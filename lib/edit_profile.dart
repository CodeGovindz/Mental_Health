import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final DateTime? initialDob;

  const EditProfilePage({Key? key, required this.initialName, required this.initialEmail, this.initialDob}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late String _email;
  DateTime? _selectedDob;
  bool _isLoading = false;
  String? _errorMessage;
  String? _avatarUrl;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    final nameParts = widget.initialName.trim().split(' ');
    _firstNameController = TextEditingController(text: nameParts.isNotEmpty ? nameParts.first : '');
    _lastNameController = TextEditingController(text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    _email = widget.initialEmail;
    _selectedDob = widget.initialDob;
    _loadAvatarUrl();
  }

  Future<void> _loadAvatarUrl() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final profile = await supabase.from('profiles').select('avatar_url').eq('id', user.id).single();
    setState(() {
      _avatarUrl = profile['avatar_url'] as String?;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final filePath = '${user.id}/avatar.png';
    try {
      await supabase.storage.from('profile-pictures').upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );
      // Get public URL (returns a string)
      final url = supabase.storage.from('profile-pictures').getPublicUrl(filePath);
      return url;
    } catch (e) {
      setState(() => _errorMessage = 'Failed to upload image.');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'User not found.');
        return;
      }
      final fullName = (_firstNameController.text.trim() + ' ' + _lastNameController.text.trim()).trim();
      String? uploadedUrl = _avatarUrl;
      if (_pickedImage != null) {
        uploadedUrl = await _uploadImage(_pickedImage!);
      }
      final updateData = {
        'name': fullName,
        if (_selectedDob != null) 'date_of_birth': _selectedDob!.toIso8601String(),
        if (uploadedUrl != null) 'avatar_url': uploadedUrl,
      };
      await supabase.from('profiles').update(updateData).eq('id', user.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to update profile.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B2B1A) : null;
    final cardColor = isDark ? const Color(0xFF223D1B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.white70 : Colors.grey[600];
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    return Scaffold(
      backgroundColor: bgColor ?? Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: isDark ? const Color(0xFF223D1B) : Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Decorative background
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
              top: -60,
              left: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.lightGreen[100]?.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              right: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.brown[100]?.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF223D1B) : Colors.brown[100],
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                              image: _pickedImage != null
                                  ? DecorationImage(
                                      image: FileImage(_pickedImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(_avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: (_pickedImage == null && (_avatarUrl == null || _avatarUrl!.isEmpty))
                                ? Icon(Icons.person, size: 48, color: isDark ? Colors.white24 : Colors.brown[300])
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.lightGreen,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor!,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _firstNameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          labelStyle: TextStyle(color: hintColor),
                          prefixIcon: Icon(Icons.person_outline, color: hintColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'First name cannot be empty' : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor!,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _lastNameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          labelStyle: TextStyle(color: hintColor),
                          prefixIcon: Icon(Icons.person, color: hintColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Last name cannot be empty' : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor!,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        initialValue: _email,
                        readOnly: true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: hintColor),
                          prefixIcon: Icon(Icons.email_outlined, color: hintColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickDateOfBirth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor!,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        child: Row(
                          children: [
                            Icon(Icons.cake_outlined, color: isDark ? Colors.white70 : Colors.brown),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _selectedDob == null
                                    ? 'Select Date of Birth'
                                    : 'DOB: ${_selectedDob!.day.toString().padLeft(2, '0')}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.year}',
                                style: TextStyle(
                                  color: _selectedDob == null ? hintColor : (isDark ? Colors.white : Colors.brown[800]),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(Icons.calendar_today, color: isDark ? Colors.white70 : Colors.brown),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF223D1B) : Colors.lightGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                        shadowColor: Colors.lightGreenAccent,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 