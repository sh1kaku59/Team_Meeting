import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class DemoScreen extends StatefulWidget {
  @override
  _DemoScreenState createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final recorder = FlutterSoundRecorder();
  final player = FlutterSoundPlayer(); // Khởi tạo FlutterSoundPlayer để phát lại âm thanh
  bool isRecording = false;
  bool isPlaying = false; // Để kiểm tra trạng thái đang phát
  String? recordedFilePath;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    recorder.openRecorder();
    player.openPlayer(); // Mở FlutterSoundPlayer
    print("Recorder and Player initialized");
  }

  Future<void> startRecording() async {
    print("Requesting microphone permission...");
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      print("Microphone permission denied");
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    recordedFilePath = '${dir.path}/recording.aac';
    print("Recording file path: $recordedFilePath");

    await recorder.startRecorder(
      toFile: recordedFilePath,
      codec: Codec.aacADTS, 
    );
    setState(() {
      isRecording = true;
    });
    print("Recording started");
  }

  Future<void> stopRecording() async {
    print("Stopping recording...");
    await recorder.stopRecorder();
    setState(() {
      isRecording = false;
    });

    print("Recording stopped, uploading to Deepgram...");
    final audioFile = File(recordedFilePath!);
    print("Dung lượng file ghi âm: ${audioFile.lengthSync()} bytes");
    await uploadToDeepgram(audioFile);
  }

  Future<void> uploadToDeepgram(File audioFile) async {
    print("Uploading audio file to Deepgram: ${audioFile.path}");

    final uri = Uri.parse('https://api.deepgram.com/v1/listen?language=vi&model=nova-2&diarize=true&punctuate=true');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Token 1f6d3a6f71092f80899f14bfe2124054ab5a7147'
      ..files.add(await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        contentType: MediaType('audio', 'aac'), // MIME type chính xác
      ));

    print("Sending request to Deepgram...");
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    print('Phản hồi từ Deepgram (raw): $responseBody');

    if (response.statusCode == 200) {
      final parsed = _parseDeepgramResponse(responseBody);
      print("Uploading transcript to Firestore: $parsed");

      await _firestore.collection('meeting_transcripts').add({
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
        'transcript': parsed,
      });

      setState(() {});
    } else {
      print('Error from Deepgram: ${response.statusCode} - $responseBody');
    }
  }

  List<Map<String, dynamic>> _parseDeepgramResponse(String jsonString) {
  final json = jsonDecode(jsonString);

  print('Deepgram response parsed: $json');  // In ra kết quả từ Deepgram

  // ✅ TH1: Có utterances (speaker diarization thành công)
  if (json['results']?['utterances'] != null) {
    final utterances = json['results']['utterances'];
    return utterances.map<Map<String, dynamic>>((utterance) {
      return {
        'speaker': 'Người số ${utterance['speaker'] + 1}',
        'text': utterance['transcript'],
      };
    }).toList();
  }

  // ✅ TH2: Chỉ có một đoạn transcript không phân speaker
  final transcriptText = json['results']?['channels']?[0]?['alternatives']?[0]?['transcript'];
  if (transcriptText != null && transcriptText.isNotEmpty) {
    return [
      {'speaker': 'Không rõ người nói', 'text': transcriptText}
    ];
  }

  // ❌ TH3: Không có gì (cải tiến thông báo lỗi)
  print('No valid transcript found');
  return [
    {'speaker': 'Hệ thống', 'text': 'Không thể chuyển âm thanh thành văn bản.'}
  ];
}



  Future<void> startPlaying() async {
    if (recordedFilePath != null && !isPlaying) {
      setState(() {
        isPlaying = true;
      });
      await player.startPlayer(
        fromURI: recordedFilePath,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() {
            isPlaying = false;
          });
        },
      );
    }
  }

  Future<void> stopPlaying() async {
    if (isPlaying) {
      await player.stopPlayer();
      setState(() {
        isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    recorder.closeRecorder();
    player.closePlayer(); // Đóng player khi dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ghi âm & Chuyển văn bản")),
      body: Column(
        children: [
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            label: Text(isRecording ? 'Dừng ghi âm' : 'Bắt đầu ghi âm'),
            onPressed: isRecording ? stopRecording : startRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: isRecording ? Colors.red : Colors.blue,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(isPlaying ? 'Dừng phát lại' : 'Phát lại ghi âm'),
            onPressed: isPlaying ? stopPlaying : startPlaying,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPlaying ? Colors.red : Colors.green,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('meeting_transcripts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Text("Chưa có bản ghi nào");
                }

                return ListView(
                  children: docs.map((doc) {
                    final data = doc['transcript'] as List<dynamic>;
                    return Card(
                      margin: EdgeInsets.all(10),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: data.map((e) {
                            return Text('${e['speaker']}: ${e['text']}',
                                style: TextStyle(fontSize: 16));
                          }).toList(),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
    