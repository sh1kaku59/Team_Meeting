import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'friend/friend_list_screen.dart';
import 'callvideo/video_call_screen.dart';
import 'profile/profile_screen.dart';
import 'demo.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  final Color zaloBlue = Color(0xFF2196F3);
  final Color lightGrey = Color(0xFFF5F5F5);

  final List<Widget> _screens = [
    FriendListScreen(),
    VideoCallScreen(),
    ProfileScreen(),
  ];

  final List<String> _titles = [
    'Danh sách bạn bè',
    'Gọi video',
    'Hồ sơ cá nhân',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: PreferredSize(
    preferredSize: Size.fromHeight(kToolbarHeight),
    child: Container(
      decoration: BoxDecoration(
        color: zaloBlue,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
    ),
  ),
  body: _screens[_selectedIndex],
  floatingActionButton: _selectedIndex == 1
    ? FloatingActionButton.extended(
        onPressed: () {
          // Điều hướng tới màn hình demo
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DemoScreen()),
          );
        },
        label: Text('Demo chức năng mới'),
        icon: Icon(Icons.new_releases),
        backgroundColor: Colors.orangeAccent,
      )
    : null,

  bottomNavigationBar: BottomNavigationBar(
    currentIndex: _selectedIndex,
    onTap: (index) {
      setState(() {
        _selectedIndex = index;
      });
    },
    backgroundColor: lightGrey,
    selectedItemColor: zaloBlue,
    unselectedItemColor: Colors.grey[600],
    selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400),
    items: [
      BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Bạn bè',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.video_call),
        label: 'Gọi video',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Hồ sơ',
      ),
    ],
  ),
);

  }
}
