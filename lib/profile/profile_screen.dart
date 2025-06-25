import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();

  bool _isEditing = false;
  File? _selectedImage;
  Uint8List? _webImage;

  final Color zaloBlue = Color(0xFF2196F3);
  final Color lightGrey = Color(0xFFF5F5F5);

  Future<DocumentSnapshot> _getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return await _firestore.collection('users').doc(user.uid).get();
    }
    throw Exception("User not logged in");
  }

  Future<void> _changePassword() async {
    try {
      User? user = _auth.currentUser;
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: _oldPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());

      Navigator.pop(context);
      _showSnackBar("Mật khẩu đã được thay đổi thành công");
    } catch (e) {
      _showSnackBar("Lỗi: ${e.toString()}");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: zaloBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _webImage = null;
        });
      }
    }
  }

  Future<String?> _uploadAvatar(String uid) async {
    final storageRef = FirebaseStorage.instance.ref().child('avatars').child('$uid.jpg');
    UploadTask uploadTask;
    if (kIsWeb && _webImage != null) {
      uploadTask = storageRef.putData(_webImage!);
    } else if (_selectedImage != null) {
      uploadTask = storageRef.putFile(_selectedImage!);
    } else {
      return null;
    }
    final TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    String? newAvatarUrl = await _uploadAvatar(user.uid);
    await _firestore.collection('users').doc(user.uid).update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      if (newAvatarUrl != null) 'avatar': newAvatarUrl,
    });

    if (_emailController.text.trim() != user.email) {
      await user.updateEmail(_emailController.text.trim());
    }

    setState(() {
      _isEditing = false;
      if (newAvatarUrl != null) {
        _avatarUrlController.text = newAvatarUrl;
      }
    });

    _showSnackBar("Thông tin đã được cập nhật");
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Đổi mật khẩu", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEditableField('Mật khẩu cũ', _oldPasswordController, obscure: true),
            SizedBox(height: 12),
            _buildEditableField('Mật khẩu mới', _newPasswordController, obscure: true),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: zaloBlue,
              side: BorderSide(color: zaloBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: zaloBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text("Xác nhận"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _getUserData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        _nameController.text = userData['name'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _emailController.text = _auth.currentUser?.email ?? '';
        _avatarUrlController.text = userData['avatar'] ?? '';

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _webImage != null
                            ? MemoryImage(_webImage!)
                            : _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : (_avatarUrlController.text.isNotEmpty)
                                    ? NetworkImage(_avatarUrlController.text)
                                        as ImageProvider
                                    : null,
                        backgroundColor: Colors.grey[300],
                        child: (_avatarUrlController.text.isEmpty &&
                                _selectedImage == null &&
                                _webImage == null)
                            ? Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: zaloBlue,
                              child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text(_nameController.text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(_emailController.text, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text("Thông tin cá nhân", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                _buildEditableField('Tên', _nameController),
                SizedBox(height: 12),
                _buildEditableField('Số điện thoại', _phoneController),
                SizedBox(height: 12),
                _buildEditableField('Email', _emailController),
                SizedBox(height: 20),
                Center(
                  child: _isEditing
                      ? _buildActionButton('Lưu thay đổi', _saveProfile)
                      : _buildActionButton('Chỉnh sửa thông tin', () => setState(() => _isEditing = true)),
                ),
                SizedBox(height: 20),
                Center(
                  child: _buildActionButton('Thay đổi mật khẩu', _showChangePasswordDialog),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: _isEditing || obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: lightGrey,
        labelText: label,
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

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: zaloBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}