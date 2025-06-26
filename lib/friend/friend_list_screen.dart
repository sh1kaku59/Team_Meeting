import 'package:flutter/material.dart';

class FriendListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Danh sách bạn bè',
        style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
        style: TextStyle(fontSize: 100, fontWeight: FontWeight.medium, color: Colors.blue),
      ),
    );
  }
}
