import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'permissions_handler.dart';
import 'transitions.dart';
import 'homepage.dart';
import 'account.dart';

class CameraAudioPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const CameraAudioPage({
    Key? key,
    required this.isDarkMode,
    required this.toggleTheme,
  }) : super(key: key);

  @override
  _CameraAudioPageState createState() => _CameraAudioPageState();
}

class _CameraAudioPageState extends State<CameraAudioPage> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  String? _localFilePath;
  int _selectedIndex = 1; // Camera/Audio Index - 1
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadAudioFile();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasCamera = await Permission.camera.isGranted;
    final hasMicrophone = await Permission.microphone.isGranted;
    
    // Check storage permissions
    bool hasStorage = false;
    if (Platform.isAndroid) {
      hasStorage = await Permission.storage.isGranted || 
                  (await Permission.photos.isGranted && 
                   await Permission.videos.isGranted);
    } else {
      hasStorage = await Permission.storage.isGranted;
    }
    
    if (!hasCamera || !hasMicrophone || !hasStorage) {
      Future.delayed(Duration.zero, () => _showPermissionDialog());
    }
  }

  Future<void> _showPermissionDialog() async {
    final List<Permission> permissions = [];
    
    if (!await Permission.camera.isGranted) permissions.add(Permission.camera);
    if (!await Permission.microphone.isGranted) permissions.add(Permission.microphone);
    
    if (Platform.isAndroid) {
      if (!await Permission.storage.isGranted) permissions.add(Permission.storage);
      if (!await Permission.photos.isGranted) permissions.add(Permission.photos);
      if (!await Permission.videos.isGranted) permissions.add(Permission.videos);
      if (!await Permission.audio.isGranted) permissions.add(Permission.audio);
    } else {
      if (!await Permission.storage.isGranted) permissions.add(Permission.storage);
    }
    
    if (permissions.isEmpty) return; // All permissions granted
    
    await PermissionsHandler.showPermissionsDialog(
      context,
      title: "Permissions Required",
      message: "Camera and microphone access are needed to use this feature. Please grant all permissions.",
      permissions: permissions,
    );
  }

  Future<void> _loadAudioFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/audio.mp3'; // replace with your file
    // simulate saving a file locally if needed
    // File(filePath).writeAsBytes(...);
    setState(() {
      _localFilePath = filePath;
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (_localFilePath != null && File(_localFilePath!).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(_localFilePath!));
        setState(() {
          _isPlaying = true;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Audio file not found")));
        return;
      }
    }
  }

  Future<void> _toggleRecording() async {
    // Check permissions before recording
    final hasMicrophone = await Permission.microphone.isGranted;
    
    // Check storage permissions
    bool hasStorage = false;
    if (Platform.isAndroid) {
      hasStorage = await Permission.storage.isGranted || 
                  (await Permission.photos.isGranted && 
                   await Permission.videos.isGranted);
    } else {
      hasStorage = await Permission.storage.isGranted;
    }
    
    if (!hasMicrophone || !hasStorage) {
      await _showPermissionDialog();
      return;
    }
    
    setState(() {
      _isRecording = !_isRecording;
    });
    
    // Here you'd implement the actual recording functionality
    if (_isRecording) {
      // Start recording
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recording started..."))
      );
    } else {
      // Stop recording
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recording stopped"))
      );
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        fadeTransition(
          HomePage(
            isDarkMode: widget.isDarkMode,
            toggleTheme: widget.toggleTheme,
          ),
        ),
      );
    } else if (index == 1) {
      // Already on Camera/Audio page
    } else if (index == 2) {
      // Stats page - not implemented
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
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera & Audio'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.green,
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: Duration(milliseconds: 400),
              child:
                  isDark
                      ? Icon(Icons.dark_mode, key: ValueKey('moon'))
                      : Icon(Icons.wb_sunny, key: ValueKey('sun')),
            ),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 60.0,
        color: Colors.lightGreen,
        backgroundColor: Colors.transparent,
        animationDuration: const Duration(milliseconds: 300),
        items: const <Widget>[
          Icon(Icons.home, size: 30, color: Colors.white),
          Icon(Icons.camera_alt, size: 30, color: Colors.white),
          Icon(Icons.stacked_bar_chart, size: 30, color: Colors.white),
          Icon(Icons.person, size: 30, color: Colors.white),
        ],
        onTap: _onNavTap,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            
            // Camera button
            ElevatedButton.icon(
              onPressed: () async {
                final hasCamera = await Permission.camera.isGranted;
                if (!hasCamera) {
                  await _showPermissionDialog();
                  return;
                }
                
                // Camera functionality would be implemented here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Camera feature will be implemented here"))
                );
              },
              icon: Icon(Icons.camera_alt),
              label: Text("Take Photo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[800] : Colors.lightGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            
            SizedBox(height: 40),
            
            // Record audio section
            Text(
              "Record Audio",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.brown[800],
              ),
            ),
            
            SizedBox(height: 16),
            
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _isRecording 
                      ? Colors.red.withOpacity(0.2) 
                      : (isDark ? Colors.grey[800] : Colors.lightGreen.withOpacity(0.2)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 50,
                  color: _isRecording ? Colors.red : (isDark ? Colors.white : Colors.lightGreen),
                ),
              ),
            ),
            
            SizedBox(height: 8),
            
            Text(
              _isRecording ? "Tap to stop recording" : "Tap to start recording",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            
            SizedBox(height: 40),
            
            // Playback section
            if (_localFilePath != null && File(_localFilePath!).existsSync())
              Column(
                children: [
                  Text(
                    "Play Recording",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.brown[800],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  IconButton(
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      size: 50,
                      color: isDark ? Colors.orangeAccent : Colors.green,
                    ),
                  ),
                  
                  Text(
                    _isPlaying ? "Playing..." : "Play",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      backgroundColor: isDark ? Colors.black : Colors.white,
    );
  }
}
