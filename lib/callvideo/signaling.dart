import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class Signaling {
  final String roomId;
  final String userId;
  final MediaStream localStream;
  Function(String userId, MediaStream? stream)? onRemoteStream;

  final Map<String, RTCPeerConnection> peerConnections = {};
  final Map<String, MediaStream> remoteStreams = {};
  final List<StreamSubscription> _subscriptions = [];

  final _db = FirebaseFirestore.instance;

  Signaling({
    required this.roomId,
    required this.userId,
    required this.localStream,
    this.onRemoteStream,
  });

  Future<void> joinRoom() async {
    print("🚪 Tham gia phòng $roomId với ID $userId");

    final participantsRef = _db.collection('rooms').doc(roomId).collection('participants');
    await participantsRef.doc(userId).set({'joinedAt': DateTime.now()});

    final sub = participantsRef.snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final otherUserId = change.doc.id;
        if (otherUserId == userId) continue;

        if (change.type == DocumentChangeType.added &&
            !peerConnections.containsKey(otherUserId)) {
          _createConnectionWith(otherUserId);
        }

        if (change.type == DocumentChangeType.removed) {
          print("👋 Người dùng $otherUserId đã rời phòng");

          peerConnections[otherUserId]?.close();
          peerConnections.remove(otherUserId);

          final removedStream = remoteStreams.remove(otherUserId);
          onRemoteStream?.call(otherUserId, null);
        }
      }
    });

    _subscriptions.add(sub);
  }

  Future<void> _createConnectionWith(String otherUserId) async {
    print("🔗 Tạo kết nối với $otherUserId");

    final config = {
  'iceServers': [
    {
      'urls': ['stun:ss-turn2.xirsys.com']
    },
    {
      'urls': [
        'turn:ss-turn2.xirsys.com:80?transport=udp',
        'turn:ss-turn2.xirsys.com:3478?transport=udp',
        'turn:ss-turn2.xirsys.com:80?transport=tcp',
        'turn:ss-turn2.xirsys.com:3478?transport=tcp',
        'turns:ss-turn2.xirsys.com:443?transport=tcp',
        'turns:ss-turn2.xirsys.com:5349?transport=tcp',
      ],
      'username':
          'n0oOQzl2gRV3BPkf3-7oalEohEm88ZIM9uanfolwgaup8TZQCD8FaHO8kALkp4IPAAAAAGgBuXFtaW5odnU=',
      'credential': '323bca3a-1bfd-11f0-94c7-0242ac140004',
    },
  ],
};


    final peer = await createPeerConnection(config);
    peerConnections[otherUserId] = peer;

    print("🎥 Thêm local tracks vào kết nối với $otherUserId");
    localStream.getTracks().forEach((track) {
      peer.addTrack(track, localStream);
    });

    peer.onTrack = (RTCTrackEvent event) {
      final stream = event.streams.first;

      print('[onTrack] Nhận track từ $otherUserId');
      print('📡 Stream ID: ${stream.id}');
      print('📡 Video tracks: ${stream.getVideoTracks().length}');
      print('📡 Audio tracks: ${stream.getAudioTracks().length}');

      if (!remoteStreams.containsKey(otherUserId)) {
        remoteStreams[otherUserId] = stream;
        onRemoteStream?.call(otherUserId, stream);
      } else {
        final existing = remoteStreams[otherUserId]!;
        if (existing.getVideoTracks().isEmpty && stream.getVideoTracks().isNotEmpty) {
          remoteStreams[otherUserId] = stream;
          onRemoteStream?.call(otherUserId, stream);
        }
      }
    };

    peer.onIceCandidate = (candidate) {
      final candidateStr = candidate.candidate ?? '';
      print('❄️ ICE raw: $candidateStr');

      final typeMatch = RegExp(r'typ (\w+)').firstMatch(candidateStr);
      final type = typeMatch != null ? typeMatch.group(1) : 'unknown';

      print('📦 Candidate type: $type');

      if (candidate != null) {
        print("📤 [ICE] Gửi candidate đến $otherUserId: ${candidate.candidate}");
        _sendIceCandidate(otherUserId, candidate);
      }
    };

    peer.onIceGatheringState = (state) {
      print("📶 ICE Gathering State: $state");
    };

    _listenIceCandidates(otherUserId);

    if (userId.compareTo(otherUserId) < 0) {
      final offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      await _sendSDP('offer', otherUserId, offer);
      print("📤 Đã tạo và gửi offer đến $otherUserId");
    } else {
      _listenSDP('offer', otherUserId, (offer) async {
        print("📥 Đã nhận offer từ $otherUserId");
        await peer.setRemoteDescription(offer);
        final answer = await peer.createAnswer();
        await peer.setLocalDescription(answer);
        await _sendSDP('answer', otherUserId, answer);
        print("📤 Đã tạo và gửi answer đến $otherUserId");
      });
    }

    _listenSDP('answer', otherUserId, (answer) async {
      print("📥 Đã nhận answer từ $otherUserId");
      await peer.setRemoteDescription(answer);
    });
  }

  Future<void> _sendSDP(String type, String toUserId, RTCSessionDescription desc) async {
    final path = _db.collection('rooms').doc(roomId)
        .collection('signals')
        .doc('${userId}_$toUserId');

    await path.set({
      'type': desc.type,
      'sdp': desc.sdp,
    });
    print("📤 Gửi $type từ $userId đến $toUserId");
  }

  void _listenSDP(String type, String fromUserId, Function(RTCSessionDescription) onReceived) {
    final path = _db.collection('rooms').doc(roomId)
        .collection('signals')
        .doc('${fromUserId}_$userId');

    final sub = path.snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data();
        if (data?['type'] == type) {
          final sdp = RTCSessionDescription(data!['sdp'], data['type']);
          print("📥 Nhận $type từ $fromUserId");
          onReceived(sdp);
        }
      }
    });

    _subscriptions.add(sub);
  }

  Future<void> _sendIceCandidate(String toUserId, RTCIceCandidate candidate) async {
    final path = _db.collection('rooms').doc(roomId)
        .collection('signals')
        .doc('${userId}_$toUserId')
        .collection('candidates');

    await path.add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
    print("📤 Gửi ICE candidate đến $toUserId");
  }

  void _listenIceCandidates(String fromUserId) {
    final path = _db.collection('rooms').doc(roomId)
        .collection('signals')
        .doc('${fromUserId}_$userId')
        .collection('candidates');

    final sub = path.snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            );
            print("📥 [ICE] Nhận candidate từ $fromUserId: ${candidate.candidate}");
            peerConnections[fromUserId]?.addCandidate(candidate);
          }
        }
      }
    });

    _subscriptions.add(sub);
  }

  Future<void> leaveRoom() async {
    print("🚪 Rời khỏi phòng $roomId với ID $userId");

    final roomRef = _db.collection('rooms').doc(roomId);
    final signalsRef = roomRef.collection('signals');

    // 0. Hủy tất cả listener
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    print("🔌 Đã huỷ toàn bộ Firestore listeners");

    // 1. Xoá khỏi participants
    await roomRef.collection('participants').doc(userId).delete();

    // 2. Xoá toàn bộ signaling liên quan
    final allSignals = await signalsRef.get();
    final relatedDocs = allSignals.docs.where((doc) =>
        doc.id.startsWith('${userId}_') || doc.id.endsWith('_$userId'));

    await Future.wait(relatedDocs.map((doc) async {
      final candidates = await doc.reference.collection('candidates').get();
      await Future.wait(candidates.docs.map((c) => c.reference.delete()));
    }));

    await Future.wait(relatedDocs.map((doc) => doc.reference.delete()));
    print("🧹 Đã xoá toàn bộ dữ liệu signaling liên quan đến $userId");

    // 3. Đóng peer connection và xoá local state
    for (var pc in peerConnections.values) {
      await pc.close();
    }
    peerConnections.clear();
    remoteStreams.clear();

    print("✅ Đã đóng toàn bộ peer connection và xoá stream");
    // Quay lại màn hình VideoCallScreen
  }



}
