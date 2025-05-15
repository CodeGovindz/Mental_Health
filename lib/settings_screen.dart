import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const SettingsScreen({Key? key, required this.onToggleTheme}) : super(key: key);
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    // Optionally, load saved settings here
  }

  void _toggleNotifications(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
  }

  void _openAppPermissions() async {
    await openAppSettings();
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. All your data is securely stored and never shared with third parties. For more details, contact support.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'मनन Mental Health App',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 मनन. All rights reserved.',
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16.0),
          child: Text('This app is designed to support your mental health journey.'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B2B1A) : null;
    final cardColor = isDark ? const Color(0xFF223D1B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? const Color(0xFF223D1B) : Colors.lightGreen[100],
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: isDark
                ? const BoxDecoration(color: Color(0xFF1B2B1A))
                : const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9CB36B), Color(0xFFF5F5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
          ),
          if (!isDark) ...[
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.lightGreen[100]?.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.brown[100]?.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
          ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SwitchListTile(
                  title: Text('Enable Notifications', style: TextStyle(color: textColor)),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  secondary: Icon(Icons.notifications_active_outlined, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
                    child: isDark
                        ? const Icon(Icons.dark_mode, key: ValueKey('moon'), color: Colors.white)
                        : const Icon(Icons.wb_sunny, key: ValueKey('sun'), color: Colors.black),
                  ),
                  title: Text('Dark Mode', style: TextStyle(color: textColor)),
                  trailing: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Switch(
                      key: ValueKey(isDark),
                      value: isDark,
                      onChanged: (_) => widget.onToggleTheme(),
                      activeColor: Colors.tealAccent,
                      inactiveThumbColor: Colors.grey,
                    ),
                  ),
                  onTap: widget.onToggleTheme,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: textColor),
                  title: Text('Privacy Policy', style: TextStyle(color: textColor)),
                  onTap: _showPrivacyPolicy,
                  trailing: Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: textColor),
                  title: Text('App Info', style: TextStyle(color: textColor)),
                  onTap: _showAppInfo,
                  trailing: Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: Icon(Icons.settings_applications_outlined, color: textColor),
                  title: Text('App Permissions', style: TextStyle(color: textColor)),
                  onTap: _openAppPermissions,
                  trailing: Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 