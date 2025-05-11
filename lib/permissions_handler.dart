import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class PermissionsHandler {
  /// Request multiple permissions at once and return results
  static Future<Map<Permission, PermissionStatus>> requestPermissions({
    bool camera = false,
    bool microphone = false,
    bool storage = false,
    bool notification = false,
  }) async {
    List<Permission> permissions = [];
    
    if (camera) permissions.add(Permission.camera);
    if (microphone) permissions.add(Permission.microphone);
    
    // Add appropriate storage permissions based on platform and Android version
    if (storage) {
      // For Android 13+ (API level 33+), we need to request specific media permissions
      if (Platform.isAndroid) {
        // These specific permissions only work for Android 13+
        permissions.add(Permission.photos); // READ_MEDIA_IMAGES
        permissions.add(Permission.videos); // READ_MEDIA_VIDEO 
        permissions.add(Permission.audio);  // READ_MEDIA_AUDIO
        
        // Also add the general storage permission for backward compatibility
        permissions.add(Permission.storage); // READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE
        permissions.add(Permission.mediaLibrary); // Additional storage access
      } else {
        // For iOS or older Android, use the general storage permission
        permissions.add(Permission.storage);
      }
    }
    
    if (notification) {
      permissions.add(Permission.notification); // POST_NOTIFICATIONS
    }

    // First request permissions
    final results = await permissions.request();
    
    // For notification permission specifically, we might need to request it separately
    // as it sometimes needs special handling
    if (notification && results[Permission.notification] != PermissionStatus.granted) {
      await Permission.notification.request();
    }
    
    return results;
  }

  /// Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    return await permission.isGranted;
  }

  /// Check if all required permissions are granted
  static Future<bool> checkAllPermissions({
    bool camera = false,
    bool microphone = false,
    bool storage = false,
    bool notification = false,
  }) async {
    // Check camera and microphone
    if (camera && !(await Permission.camera.isGranted)) return false;
    if (microphone && !(await Permission.microphone.isGranted)) return false;
    
    // Check storage based on platform and Android version
    if (storage) {
      if (Platform.isAndroid) {
        // On Android 13+, check specific media permissions
        final hasStorage = (await Permission.storage.isGranted) ||
                          ((await Permission.photos.isGranted) &&
                           (await Permission.videos.isGranted) &&
                           (await Permission.audio.isGranted));
        if (!hasStorage) return false;
      } else {
        // On iOS or older Android, check the general storage permission
        if (!(await Permission.storage.isGranted)) return false;
      }
    }
    
    // Check notification
    if (notification && !(await Permission.notification.isGranted)) return false;
    
    return true;
  }

  /// Show permissions dialog with explanation
  static Future<bool> showPermissionsDialog(
    BuildContext context, {
    required String title,
    required String message,
    required List<Permission> permissions,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Settings'),
              onPressed: () async {
                Navigator.of(context).pop(true);
                await openAppSettings();
              },
            ),
            TextButton(
              child: const Text('Request'),
              onPressed: () async {
                Navigator.of(context).pop(true);
                
                // Request each permission individually for better user experience
                for (var permission in permissions) {
                  await permission.request();
                }
              },
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
} 