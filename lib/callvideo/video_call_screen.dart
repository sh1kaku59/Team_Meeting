import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'call_screen.dart';

class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _roomIdController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isLoading = false;

  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  final Color zaloBlue = Color(0xFF2196F3);
  final Color lightGrey = Color(0xFFF5F5F5);

  List<String> recentRoomIds = ['123456', '654321', '999888']; // giả lập

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
    });

    String userId = FirebaseAuth.instance.currentUser!.uid;
    var roomId = DateTime.now().millisecondsSinceEpoch.toString();

    await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
      'roomId': roomId,
      'createdAt': Timestamp.now(),
      'owner': userId,
    });

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Phòng $roomId đã được tạo!")));
  }

  Future<void> _joinRoom(String roomId) async {
    setState(() {
      _isLoading = true;
    });

    var roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get();
    if (roomDoc.exists) {
      setState(() {
        _isLoading = false;
      });

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CallScreen(roomId: roomId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
      });
      _shakeKey.currentState?.shake();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không tìm thấy phòng!")),
      );
    }
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inHours < 24) {
      return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    } else {
      return "${time.day}/${time.month}/${time.year}";
    }
  }

  // Add a function to assign different colors to roles
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin':
        return const Color.fromARGB(255, 251, 186, 89); // Red for Admin
      case 'Member':
        return const Color.fromARGB(255, 96, 221, 101); // Green for Member
      default:
        return const Color.fromARGB(255, 93, 182, 255); // Default color
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20),
              AnimatedCreateRoomButton(
                isLoading: _isLoading,
                onPressed: _createRoom,
              ),
              SizedBox(height: 16),
              ShakeWidget(
                key: _shakeKey,
                child: TextField(
                  controller: _roomIdController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) _joinRoom(value.trim());
                  },
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Tham gia phòng theo ID...",
                    prefixIcon: Icon(Icons.search, color: zaloBlue),
                    filled: true,
                    fillColor: _isFocused ? Colors.white : lightGrey,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: zaloBlue, width: 2),
                    ),
                    suffixIcon: _roomIdController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, color: Colors.grey),
                            onPressed: () {
                              _roomIdController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
              if (_roomIdController.text.isEmpty) ...[
                SizedBox(height: 12),
                Text("Phòng gần đây",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: recentRoomIds
                      .map((id) => ActionChip(
                            label: Text(id),
                            onPressed: () => _joinRoom(id),
                            backgroundColor: zaloBlue.withOpacity(0.1),
                            labelStyle: TextStyle(color: zaloBlue),
                          ))
                      .toList(),
                ),
              ],
              SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: zaloBlue))
                    : FutureBuilder<QuerySnapshot>( 
                        future: FirebaseFirestore.instance
                            .collection('rooms')
                            .orderBy('createdAt', descending: true)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(child: Text("🚫 Không có phòng nào!"));
                          }

                          var rooms = snapshot.data!.docs;

                          return GridView.count(
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                            children: List.generate(rooms.length, (index) {
                              var room = rooms[index];
                              var roomId = room['roomId'];
                              Timestamp createdAt = room['createdAt'];
                              DateTime dateTime = createdAt.toDate();

                              // Thêm tag vai trò (Role)
                              final roleTags = ['Admin', 'Member', 'Guest'];
                              final roleTag = roleTags[index % roleTags.length];
                              
                              return Hero(
                                tag: roomId, // Thêm hiệu ứng Hero
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _joinRoom(roomId),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.8),
                                            Colors.blue.withOpacity(0.1),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color.fromARGB(255, 161, 161, 161).withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.blue.withOpacity(0.2),
                                          width: 0.5,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(5),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Icon(Icons.meeting_room,
                                              color: zaloBlue, size: 28),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Phòng: $roomId",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                "Tạo lúc: ${_formatDateTime(dateTime)}",
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              // Thêm Tag vai trò với màu sắc khác nhau
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getRoleColor(roleTag),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  roleTag,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget shake (unchanged)
class ShakeWidget extends StatefulWidget {
  final Widget child;

  const ShakeWidget({required Key key, required this.child}) : super(key: key);

  @override
  ShakeWidgetState createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: Duration(milliseconds: 400), vsync: this);
    _animation = TweenSequence([ 
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        return Transform.translate(offset: Offset(_animation.value, 0), child: child);
      },
      child: widget.child,
    );
  }
}

class AnimatedCreateRoomButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const AnimatedCreateRoomButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  _AnimatedCreateRoomButtonState createState() =>
      _AnimatedCreateRoomButtonState();
}

class _AnimatedCreateRoomButtonState extends State<AnimatedCreateRoomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedCreateRoomButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading) {
      _iconController.repeat();
    } else {
      _iconController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.03 : 1.0,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
              if (_isHovering)
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Center(
                child: widget.isLoading
                    ? RotationTransition(
                        turns: _iconController,
                        child: Icon(Icons.autorenew, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "Tạo Phòng Mới",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
