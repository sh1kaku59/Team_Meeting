// ⚠️ Cập nhật Signaling class của bạn để vẫn giữ nguyên chức năng gọi, không cần sửa phần đó

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signaling.dart';
import 'chat_screen.dart';

class CallScreen extends StatefulWidget {
  final String roomId;
  const CallScreen({required this.roomId, super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  MediaStream? _localStream;
  Signaling? _signaling;

  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _useFrontCamera = true;
  bool _isRoomOwner = false;
  bool _isMutedByHost = false;

  late String userId;
  late String roomId;

  @override
  void initState() {
    super.initState();
    roomId = widget.roomId;
    userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _startCallSetup();
    _listenKickSignal();
    _listenMuteSignal();
  }

  void _listenKickSignal() {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('signals')
        .doc(userId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data()?['type'] == 'kick') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Bạn đã bị đuổi khỏi phòng'),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _signaling?.leaveRoom();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    await FirebaseFirestore.instance
                        .collection('rooms')
                        .doc(roomId)
                        .collection('signals')
                        .doc(userId)
                        .delete();
                  },
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  void _listenMuteSignal() {
  FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .collection('mute')
      .doc(userId)
      .snapshots()
      .listen((doc) {
    if (doc.exists) {
      final data = doc.data()!;
      final mic = data['mic'] ?? false;
      final cam = data['cam'] ?? false;

      setState(() {
        _isMutedByHost = mic || cam;
      });

      // Cập nhật track audio
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = !mic; // Nếu mic bị mute, tắt track
        // Nếu không cần bật lại, có thể gọi track.stop() và tạo lại track khi unmute
      });

      // Cập nhật track video
      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = !cam; // Nếu cam bị mute, tắt track
        // Nếu không cần bật lại, có thể gọi track.stop() và tạo lại track khi unmute
      });
    } else {
      setState(() {
        _isMutedByHost = false;
      });

      // Khi unmute, có thể cần khởi tạo lại track để đảm bảo chúng hoạt động đúng
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = true;  // Mở lại mic nếu unmute
      });

      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = true;  // Mở lại camera nếu unmute
      });
    }
  });
}


  Future<void> _startCallSetup() async {
    await _localRenderer.initialize();
    final granted = await _requestPermissions();
    if (!granted) {
      _showPermissionDeniedDialog();
      return;
    }

    await _startLocalStream();

    final roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get();
    final roomOwner = roomDoc.data()?['owner'];

    setState(() {
      _isRoomOwner = userId == roomOwner;
    });

    _signaling = Signaling(
      roomId: roomId,
      userId: userId,
      localStream: _localStream!,
      onRemoteStream: (remoteUserId, remoteStream) async {
        if (remoteStream == null) {
          final renderer = _remoteRenderers.remove(remoteUserId);
          await renderer?.dispose();
          setState(() {});
          return;
        }

        final remoteRenderer = RTCVideoRenderer();
        await remoteRenderer.initialize();
        remoteRenderer.srcObject = remoteStream;

        setState(() {
          _remoteRenderers[remoteUserId] = remoteRenderer;
        });
      },
    );

    await _signaling!.joinRoom();
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _startLocalStream() async {
    final constraints = {
      'video': {'facingMode': _useFrontCamera ? 'user' : 'environment'},
      'audio': true,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _localRenderer.srcObject = _localStream;
  }

  void _toggleMic() {
    if (_isMutedByHost) return;
    final audioTrack = _localStream?.getAudioTracks().first;
    if (audioTrack != null) {
      setState(() {
        _micEnabled = !_micEnabled;
        audioTrack.enabled = _micEnabled;
      });
    }
  }

  void _toggleCamera() {
    if (_isMutedByHost) return;
    final videoTrack = _localStream?.getVideoTracks().first;
    if (videoTrack != null) {
      setState(() {
        _camEnabled = !_camEnabled;
        videoTrack.enabled = _camEnabled;
      });
    }
  }

  Future<void> _switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().first;
    if (videoTrack != null) {
      try {
        await Helper.switchCamera(videoTrack);
        setState(() {
          _useFrontCamera = !_useFrontCamera;
        });
      } catch (e) {
        print("❌ Lỗi khi đổi camera: $e");
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Permission denied'),
        content: Text('Camera và microphone là bắt buộc để tham gia cuộc gọi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          )
        ],
      ),
    );
  }

  void _showChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (_) => ChatScreen(roomId: roomId),
    );
  }

  void _showParticipantList() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    isScrollControlled: true,
    builder: (_) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Người tham gia", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(roomId)
                    .collection('participants')
                    .snapshots(),
                builder: (context, participantSnapshot) {
                  if (!participantSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userIds = participantSnapshot.data!.docs.map((doc) => doc.id).toList();

                  return ListView.builder(
                    itemCount: userIds.length,
                    itemBuilder: (context, index) {
                      final userId = userIds[index];
                      final isMyself = userId == this.userId;

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(roomId)
                            .collection('mute')
                            .doc(userId)
                            .snapshots(),
                        builder: (context, muteSnapshot) {
                          final isMuted = muteSnapshot.data?.exists ?? false;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const ListTile(title: Text('Đang tải...', style: TextStyle(color: Colors.white)));
                              }

                              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                              final userName = userData['name'] ?? 'Không tên';
                              final userAvatar = userData['avatar'];

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                                  child: userAvatar == null ? const Icon(Icons.person) : null,
                                ),
                                title: Text(userName, style: const TextStyle(color: Colors.white)),
                                subtitle: isMuted
                                    ? const Text("🔇 Đang bị mute", style: TextStyle(color: Colors.red))
                                    : null,
                                trailing: _isRoomOwner && !isMyself
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isMuted ? Icons.volume_up : Icons.volume_off,
                                              color: Colors.white,
                                            ),
                                            onPressed: () async {
                                              final muteRef = FirebaseFirestore.instance
                                                  .collection('rooms')
                                                  .doc(roomId)
                                                  .collection('mute')
                                                  .doc(userId);
                                              if (isMuted) {
                                                await muteRef.delete(); // Unmute
                                              } else {
                                                await muteRef.set({'mic': true, 'cam': true}); // Mute
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                            onPressed: () async {
                                              await _kickUser(userId);
                                            },
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}


  Future<void> _kickUser(String userIdToKick) async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('signals')
        .doc(userIdToKick)
        .set({'type': 'kick', 'timestamp': FieldValue.serverTimestamp()});

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userIdToKick)
        .delete();
  }

  Widget _buildVideoView(String label, RTCVideoRenderer renderer, {bool mirror = false}) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: Column(
        children: [
          Text(
            renderer.srcObject != null ? "🟢 $label" : "🔴 $label: chưa có stream",
            style: TextStyle(color: Colors.white),
          ),
          Expanded(child: RTCVideoView(renderer, mirror: mirror)),
          if (_isMutedByHost && label == 'Local')
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text("🔇 Bạn đang bị mute bởi chủ phòng", style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoLayout() {
    final remoteEntries = _remoteRenderers.entries.toList();

    if (remoteEntries.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: _buildVideoView('Local', _localRenderer, mirror: true),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: remoteEntries.length >= 2 ? 2 : 1,
      children: [
        _buildVideoView('Local', _localRenderer, mirror: true),
        ...remoteEntries.map(
          (entry) => _buildVideoView('Remote ${entry.key}', entry.value),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    for (var renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildVideoLayout()),
            Positioned(
              top: 16,
              right: 16,
              child: _buildControlButton(icon: Icons.people, onTap: _showParticipantList),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _buildControlButton(icon: Icons.chat, onTap: _showChat),
            ),
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _micEnabled ? Icons.mic : Icons.mic_off,
                    onTap: _toggleMic,
                  ),
                  _buildControlButton(
                    icon: _camEnabled ? Icons.videocam : Icons.videocam_off,
                    onTap: _toggleCamera,
                  ),
                  _buildControlButton(
                    icon: Icons.cameraswitch,
                    onTap: _switchCamera,
                  ),
                  _buildControlButton(
                    icon: Icons.call_end,
                    onTap: () async {
                      await _signaling?.leaveRoom();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onTap,
    );
  }
}
