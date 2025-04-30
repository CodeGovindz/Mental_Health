import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for date formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Import to access the supabase client
import 'signin.dart';

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const HomePage({Key? key, required this.isDarkMode, required this.toggleTheme}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = "User";
  String _userEmail = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Check authentication status first
    _checkAuthStatus();
    _loadUserProfile();
  }

  Future<void> _checkAuthStatus() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      // Not authenticated, go back to login
      debugPrint('User is not authenticated, redirecting to sign in');
      if (mounted) {
        _navigateToSignIn();
      }
      return;
    }
    
    // Set up a listener for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        debugPrint('Auth state changed: User signed out');
        if (mounted) {
          _navigateToSignIn();
        }
      }
    });
  }

  void _navigateToSignIn() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SignInPage(
          onSignInSuccess: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomePage(
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
      // Get current user
      final User? user = supabase.auth.currentUser;
      
      if (user != null) {
        // Get profile data
        final profileData = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        
        setState(() {
          _userName = profileData['name'] ?? 'User';
          _userEmail = user.email ?? '';
        });
      }
    } catch (e) {
      // Handle error
      debugPrint('Error loading profile: $e');
      // Still show something to the user
      final user = supabase.auth.currentUser;
      if (user != null && mounted) {
        setState(() {
          _userName = 'User';
          _userEmail = user.email ?? '';
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
      // Show error to user
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

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Combined Calendar, Profile, and Search Bar Section
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                color: Colors.lightGreen[100], // Light green background
                padding: EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  16,
                ), // Increased top padding
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.deepOrange,
                            ),
                            SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 14,
                              ), // Reduced font size
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.notifications_none, size: 28),
                            SizedBox(width: 16),
                            GestureDetector(
                              onTap: _signOut,
                              child: Icon(Icons.logout, size: 24),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start, // Align items to the start
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.brown[700],
                          child: Text(
                            _isLoading ? '?' : _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
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
                            padding: const EdgeInsets.only(
                              top: 6.0,
                            ), // Add a little top padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLoading ? 'Loading...' : _userName,
                                  style: TextStyle(
                                    fontSize: 18, // Reduced font size
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
                    SizedBox(height: 16), // Increased spacing before search bar
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

            // Chatbot Section
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

      // Bottom Navigation Bar with Curves
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Stats',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
