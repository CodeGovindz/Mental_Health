import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'signin.dart';
import 'homepage.dart';
import 'transitions.dart';
import 'package:flutter/services.dart';
import 'edit_profile.dart';
import 'package:http/http.dart' as http;

class AccountPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const AccountPage({
    Key? key,
    required this.isDarkMode,
    required this.toggleTheme,
  }) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _userName = "User";
  String _userEmail = "";
  bool _isLoading = true;
  bool _isDeleting = false;

  int _selectedIndex = 3; // Account Index - 3

  @override
  void initState() {
    super.initState();
    // Set the status bar color to light green
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.lightGreen[100],
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profile =
            await supabase.from('profiles').select().eq('id', user.id).single();

        setState(() {
          _userName = profile['name'] ?? 'User';
          _userEmail = user.email ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      final user = supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          _userName = 'User';
          _userEmail = user.email ?? '';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SignInPage(onSignInSuccess: () {}),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Sign out error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error signing out.')));
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          initialName: _userName,
          initialEmail: _userEmail,
        ),
      ),
    );
    if (result == true) {
      // Refresh profile after editing
      _loadUserProfile();
    }
  }

  Future<void> _deleteAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _isDeleting = true);
    try {
      final response = await http.post(
        Uri.parse('https://cqfwjwrhhcctazigevno.supabase.co/functions/v1/delete_user_account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken ?? ''}',
        },
        body: '{"user_id": "${user.id}"}',
      );
      if (response.statusCode == 200) {
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => SignInPage(onSignInSuccess: () {}),
            ),
            (route) => false,
          );
        }
      } else {
        throw Exception('Failed to delete account');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Do you really want to delete your account? This action cannot be undone.'),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[900],
                    elevation: 4,
                    shadowColor: Colors.red[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isDeleting
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _deleteAccount();
                        },
                  child: _isDeleting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Yes, Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add your own navigation logic here
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        fadeTransition(
          HomePage(
            isDarkMode: widget.isDarkMode,
            toggleTheme: widget.toggleTheme,
          ),
        ),
        // context,
        // MaterialPageRoute(
        //   builder:
        //       (context) => HomePage(
        //         isDarkMode: widget.isDarkMode,
        //         toggleTheme: widget.toggleTheme,
        //       ),
        // ),
      );
    } else if (index == 1) {
      // Navigator.pushReplacementNamed(context, '/chat');
    } else if (index == 2) {
      //Stats
    } else if (index == 3) {
      // Already on Account
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.lightGreen[100],
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    return Scaffold(
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
      body: SafeArea(
        child: Column(
          children: [
            // Header with profile and theme toggle
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                color: Colors.lightGreen[100],
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.brown[700],
                      child: Text(
                        _isLoading
                            ? '?'
                            : _userName.isNotEmpty
                            ? _userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoading ? 'Loading...' : _userName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                    IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (child, animation) => RotationTransition(
                              turns: animation,
                              child: child,
                            ),
                        child:
                            widget.isDarkMode
                                ? const Icon(
                                  Icons.dark_mode,
                                  key: ValueKey('moon'),
                                )
                                : const Icon(
                                  Icons.wb_sunny,
                                  key: ValueKey('sun'),
                                ),
                      ),
                      onPressed: widget.toggleTheme,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text("Edit Profile"),
                    onTap: _navigateToEditProfile,
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Settings"),
                    onTap: () {
                      // Future: Navigate to settings page
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Log Out"),
                    onTap: _signOut,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text("Delete Account"),
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
