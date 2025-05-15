import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin.dart';
import 'main.dart'; // Import to access the supabase client
import 'package:flutter/services.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController(); // Added name field
  bool _isEmailValid = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false; // Added loading state
  String? _errorMessage; // Added error message

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
  }

  void _validateEmail(String value) {
    setState(() {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      _isEmailValid = emailRegex.hasMatch(value) || value.isEmpty;
    });
  }

  Future<void> _signUp() async {
    if (_emailController.text.isEmpty) {
      setState(() => _isEmailValid = false);
      return;
    }

    if (!_isEmailValid) return;

    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Password cannot be empty');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sign up with Supabase
      final AuthResponse response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // If sign up successful
      if (response.user != null) {
        try {
          // Try to create profile in the profiles table
          await supabase.from('profiles').insert({
            'id': response.user!.id,
            'email': _emailController.text.trim(),
            'name': _nameController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (profileError) {
          // Log profile creation error but don't show to user since auth worked
          debugPrint('Error creating profile: $profileError');
        }

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign up successful! Please check your email to verify your account. Click the link in the email to complete registration.'),
              duration: Duration(seconds: 8),
            ),
          );
          
          // Show a dialog with more detailed instructions
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Email Verification Required'),
              content: const Text(
                'An email with a verification link has been sent to your email address. '
                'Please check your inbox and click the link to verify your account.\n\n'
                'The link will open in your browser and then redirect back to this app.'
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    
                    // Navigate back to sign in page
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignInPage(
                          onSignInSuccess: () {
                            // This will be handled by the main app when actually signing in
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      debugPrint('Signup error: $error');
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Green curved header with logo
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    color: Color(0xFF9CB36B),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(100),
                      bottomRight: Radius.circular(100),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/logo.png', width: 60, height: 60),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Sign Up For Free text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Sign Up For Free',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A2713),
                ),
                textAlign: TextAlign.left,
              ),
            ),

            const SizedBox(height: 32),

            // Display error message if any
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFEE9155),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(50),
                    color: const Color(0xFFFFF3ED),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEE9155),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF663B1E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            const SizedBox(height: 16),

            // Full Name field
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Full Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A2713),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Name input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFEE9155),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF3A2713),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Email Address
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Email Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A2713),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Email input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFEE9155),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: _validateEmail,
                  decoration: InputDecoration(
                    hintText: 'Enter your email...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF3A2713),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Invalid Email Message
            if (!_isEmailValid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFEE9155),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(50),
                    color: const Color(0xFFFFF3ED),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEE9155),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Invalid Email Address!!!',
                        style: TextStyle(color: Color(0xFF663B1E)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Password
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A2713),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Password input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFEE9155),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Enter your password...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF3A2713),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Password Confirmation
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Password Confirmation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A2713),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Confirm Password input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFEE9155),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Confirm your password...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF3A2713),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Sign Up Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C3921),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Already have an account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(color: Color(0xFF666666)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignInPage(
                          onSignInSuccess: () {
                            // This will be handled by the main app when actually signing in
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Color(0xFFEE9155),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
