import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'call_screen.dart';  // Đảm bảo đã nhập đúng file chứa CallScreen

class StreamSetupScreen extends StatefulWidget {
  final String roomId;

  StreamSetupScreen({required this.roomId});

  @override
  _StreamSetupScreenState createState() => _StreamSetupScreenState();
}

class _StreamSetupScreenState extends State<StreamSetupScreen> {
  bool _isCameraEnabled = true;
  bool _isMicEnabled = true;
  MediaStream? _localStream;
  late RTCVideoRenderer _localRenderer;

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _initializeRenderer();
    _checkPermissions();
  }

  Future<void> _initializeRenderer() async {
    await _localRenderer.initialize();
  }

  Future<void> _checkPermissions() async {
    var cameraStatus = await Permission.camera.request();
    var micStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && micStatus.isGranted) {
      await _initializeMedia();
    } else {
      print("Quyền truy cập camera hoặc mic bị từ chối.");
    }
  }

  Future<void> _initializeMedia() async {
  try {
    // Nếu stream đã có, kiểm tra lại trạng thái các track trước khi tạo mới
    if (_localStream != null) {
      // Lấy các track audio và video hiện tại
      var audioTrack = _localStream!.getAudioTracks().isNotEmpty ? _localStream!.getAudioTracks().first : null;
      var videoTrack = _localStream!.getVideoTracks().isNotEmpty ? _localStream!.getVideoTracks().first : null;

      // Nếu chỉ thay đổi audio (mic) thì update mic track
      if (audioTrack != null && _isMicEnabled != audioTrack.enabled) {
        audioTrack.enabled = _isMicEnabled;
      }

      // Nếu chỉ thay đổi video (camera) thì update video track
      if (videoTrack != null && _isCameraEnabled != videoTrack.enabled) {
        videoTrack.enabled = _isCameraEnabled;
      }

      // Nếu mic và camera không thay đổi, không cần tạo lại stream
      if ((audioTrack == null || audioTrack.enabled == _isMicEnabled) && 
          (videoTrack == null || videoTrack.enabled == _isCameraEnabled)) {
        return;
      }
      
      // Nếu mic hoặc camera thay đổi, tạo lại stream với track mới
      await _localStream!.dispose();  // Dispose stream cũ
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': _isMicEnabled,
        'video': _isCameraEnabled,
      });

      setState(() {
        _localRenderer.srcObject = _localStream;  // Gán lại stream mới vào renderer
      });
    } else {
      // Nếu stream chưa có, tạo mới stream
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': _isMicEnabled,
        'video': _isCameraEnabled,
      });

      setState(() {
        _localRenderer.srcObject = _localStream;
      });
    }
  } catch (e) {
    print("Lỗi khi lấy stream: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 10),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: (_isCameraEnabled && _localStream != null)
                    ? RTCVideoView(_localRenderer, mirror: true)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off, size: 150, color: Colors.blue),
                          SizedBox(height: 10),
                          Text("Camera đang tắt", style: TextStyle(fontSize: 16)),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text("Bật Camera"),
                    value: _isCameraEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _isCameraEnabled = value;
                      });
                      _initializeMedia();
                      print("Mic: ${_isMicEnabled ? 1 : 0}, Camera: ${value ? 1 : 0}");
                    },
                  ),
                  SwitchListTile(
                    title: Text("Bật Mic"),
                    value: _isMicEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _isMicEnabled = value;
                      });
                      _initializeMedia();
                      print("Mic: ${value ? 1 : 0}, Camera: ${_isCameraEnabled ? 1 : 0}");
                    },
                  ),
                  SizedBox(height: 10),
                  Text("Trạng thái hiện tại:", style: TextStyle(fontWeight: FontWeight.bold)),
Text("Audio: ${_localStream?.getAudioTracks().isNotEmpty == true && _localStream!.getAudioTracks().first.enabled ? 1 : 0}"),
Text("Camera: ${_localStream?.getVideoTracks().isNotEmpty == true && _localStream!.getVideoTracks().first.enabled ? 1 : 0}"),

                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallScreen(
                            roomId: widget.roomId,
                            localStream: _localStream, // Truyền stream vào CallScreen
                          ),
                        ),
                      );
                    },
                    child: Text("Vào Cuộc Gọi"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    super.dispose();
  }
}
