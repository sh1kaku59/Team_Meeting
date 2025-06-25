import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class InfoScreen extends StatefulWidget {
  @override
  _InfoScreenState createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _avatarImage;

  final Color zaloBlue = Color(0xFF2196F3);
  final Color lightGrey = Color(0xFFF5F5F5);

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _avatarImage = File(picked.path);
      });
    }
  }

  Future<void> _submitInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      String? avatarUrl;

      if (_avatarImage != null) {
        // Upload ảnh lên Firebase Storage nếu bạn muốn, ở đây mình chỉ đơn giản bỏ qua bước đó
        avatarUrl = "https://example.com/fake-avatar-url.png";
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatar': avatarUrl ?? '',
        'email': FirebaseAuth.instance.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.85),
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[800]),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: zaloBlue, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        backgroundColor: zaloBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        textStyle: TextStyle(fontSize: 16),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: zaloBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    _avatarImage != null ? FileImage(_avatarImage!) : null,
                child: _avatarImage == null ? Icon(Icons.add_a_photo) : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField('Họ và Tên', _nameController),
            SizedBox(height: 12),
            _buildTextField('Số điện thoại', _phoneController),
            const SizedBox(height: 20),
            _buildActionButton('Lưu và tiếp tục', _submitInfo),
          ],
        ),
      ),
    );
  }
}
