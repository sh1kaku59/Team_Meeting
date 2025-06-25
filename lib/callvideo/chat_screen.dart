import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({required this.roomId, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'userId': _currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _controller.clear();
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$h:$m $d/$mo/$y';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(widget.roomId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final msg = messages[index];
                      final userId = msg['userId'] ?? '';
                      final text = msg['text'] ?? '';
                      final timestamp = msg['timestamp'] as Timestamp?;

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (_, userSnap) {
                          final userData = userSnap.data?.data() as Map<String, dynamic>?;

                          final name = userData?['name'] ?? 'Không tên';
                          final avatar = userData?['avatar'];
                          final timeStr = _formatTimestamp(timestamp);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null ? Icon(Icons.person) : null,
                            ),
                            title: Text(name, style: TextStyle(color: Colors.white)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(text, style: TextStyle(color: Colors.white70)),
                                SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[300]),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Divider(color: Colors.grey),
            Padding(
              padding: EdgeInsets.only(
                  left: 16, right: 8, bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.orangeAccent),
                    onPressed: _sendMessage,
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
