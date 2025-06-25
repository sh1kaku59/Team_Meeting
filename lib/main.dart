import 'package:flutter/material.dart';
import 'firebase_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'info.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initializeFirebase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
        '/auth': (context) => AuthScreen(),
        '/home': (context) => HomeScreen(),
        '/info': (context) => InfoScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return HomeScreen();
        } else {
          return AuthScreen();
        }
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _resetEmailController = TextEditingController();

  bool isLogin = true;
  bool isResetPassword = false;

  final Color zaloBlue = Color(0xFF2196F3);
  final Color lightGrey = Color(0xFFF5F5F5);

  Future<void> _authenticate() async {
    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.of(context).pushReplacementNamed('/info');
      }
      _showSnackBar(isLogin ? 'Đăng nhập thành công' : 'Đăng ký thành công');
    } catch (e) {
      _showSnackBar('Lỗi: ${e.toString()}');
    }
  }

  Future<void> _resetPassword() async {
    if (_resetEmailController.text.isEmpty) {
      _showSnackBar('Vui lòng nhập email để đặt lại mật khẩu');
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _resetEmailController.text.trim());
      _showSnackBar('Hãy kiểm tra email để đặt lại mật khẩu');
      setState(() {
        _resetEmailController.clear();
        isResetPassword = false;
      });
    } catch (e) {
      _showSnackBar('Lỗi: ${e.toString()}');
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

  void _goBackToLogin() {
    setState(() {
      _resetEmailController.clear();
      _emailController.clear();
      _passwordController.clear();
      isResetPassword = false;
    });
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

  Widget _buildTextLink(String text, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: zaloBlue,
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: Text(text),
    );
  }

  Widget _buildResetPasswordUI() {
    return Column(
      key: ValueKey('reset'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTextField('Nhập email để đặt lại mật khẩu', _resetEmailController),
        SizedBox(height: 20),
        _buildActionButton('Gửi yêu cầu đặt lại mật khẩu', _resetPassword),
        SizedBox(height: 12),
        _buildTextLink('Quay lại', _goBackToLogin),
      ],
    );
  }

  Widget _buildLoginRegisterUI() {
    return Column(
      key: ValueKey('auth'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTextField('Email', _emailController),
        SizedBox(height: 12),
        _buildTextField('Mật khẩu', _passwordController, obscure: true),
        SizedBox(height: 20),
        _buildActionButton(isLogin ? 'Đăng nhập' : 'Đăng ký', _authenticate),
        SizedBox(height: 12),
        if (isLogin)
          _buildTextLink('Quên mật khẩu?', () => setState(() => isResetPassword = true)),
        SizedBox(height: 12),
        _buildTextLink(
          isLogin ? 'Chưa có tài khoản? Đăng ký' : 'Đã có tài khoản? Đăng nhập',
          () {
            setState(() {
              isLogin = !isLogin;
              _emailController.clear();
              _passwordController.clear();
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [zaloBlue, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.white),
                  SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Container(
                      key: ValueKey(isResetPassword),
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isResetPassword ? _buildResetPasswordUI() : _buildLoginRegisterUI(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
