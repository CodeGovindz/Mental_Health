import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for date formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Import to access the supabase client
import 'signin.dart';
import 'account.dart'; // Import to access the AccountPage
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'transitions.dart'; // Import for custom transitions

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const HomePage({
    Key? key,
    required this.isDarkMode,
    required this.toggleTheme,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = "User";
  String _userEmail = "";
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _loadUserProfile();
  }

  Future<void> _checkAuthStatus() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      debugPrint('User is not authenticated, redirecting to sign in');
      _navigateToSignIn();
    } else {
      supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.signedOut) {
          debugPrint('Auth state changed: User signed out');
          _navigateToSignIn();
        }
      });
    }
  }

  void _navigateToSignIn() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (context) => SignInPage(
              onSignInSuccess: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder:
                        (context) => HomePage(
                          isDarkMode: widget.isDarkMode,
                          toggleTheme: widget.toggleTheme,
                        ),
                  ),
                );
              },
            ),
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final User? user = supabase.auth.currentUser;

      if (user != null) {
        final profileData =
            await supabase.from('profiles').select().eq('id', user.id).single();

        setState(() {
          _userName = profileData['name'] ?? 'User';
          _userEmail = user.email ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _userName = 'User';
          _userEmail = 'Email not found';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        _navigateToSignIn();
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add your own navigation logic here
    if (index == 0) {
      //Already on Home
    } else if (index == 1) {
      // Navigator.pushReplacementNamed(context, '/chat');
    } else if (index == 2) {
      //Stats
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        fadeTransition(
          AccountPage(
            isDarkMode: widget.isDarkMode,
            toggleTheme: widget.toggleTheme,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                color: Colors.lightGreen[100],
                padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.today, color: Colors.brown),
                            SizedBox(width: 8),
                            Text(formattedDate, style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.notifications_none,
                                size: 24,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.brown[700],
                          child: Text(
                            _isLoading
                                ? '?'
                                : _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLoading ? 'Loading...' : _userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  _isLoading ? '' : _userEmail,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: Duration(milliseconds: 400),
                            transitionBuilder:
                                (child, animation) => RotationTransition(
                                  turns: animation,
                                  child: child,
                                ),
                            child:
                                widget.isDarkMode
                                    ? Icon(
                                      Icons.dark_mode,
                                      key: ValueKey('moon'),
                                    )
                                    : Icon(
                                      Icons.wb_sunny,
                                      key: ValueKey('sun'),
                                    ),
                          ),
                          onPressed: widget.toggleTheme,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          Icon(Icons.search),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Image.network(
                    "https://cdn-icons-png.flaticon.com/512/4712/4712027.png",
                    height: 60,
                    width: 60,
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Chatbot",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text("Your virtual assistant"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 60.0,
        color: Colors.lightGreen,
        backgroundColor: Colors.transparent,
        animationDuration: const Duration(milliseconds: 300),
        items: const <Widget>[
          Icon(Icons.home, size: 30, color: Colors.white),
          Icon(Icons.chat, size: 30, color: Colors.white),
          Icon(Icons.stacked_bar_chart, size: 30, color: Colors.white),
          Icon(Icons.person, size: 30, color: Colors.white),
        ],
        onTap: _onNavTap,
      ),
    );
  }
}
