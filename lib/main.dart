import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'homepage.dart';
import 'signin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://cqfwjwrhhcctazigevno.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNxZndqd3JoaGNjdGF6aWdldm5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU3NTE2ODQsImV4cCI6MjA2MTMyNzY4NH0.sEu1Xeni4rw3g9vaKI1nEtfZca5CFvdiexPOmLTwJ-8',
    debug: true,
  );
  
  runApp(const MyApp());
}

// Get Supabase client instance to use throughout the app
final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  late AppLinks _appLinks;
  bool _initialURILinkHandled = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    initializeDeepLinks();
    // Check if user is already signed in
    _checkAndNavigateToHome();
  }
  
  Future<void> _checkAndNavigateToHome() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      // Wait a bit to ensure the app is fully initialized
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToHome();
      });
    }
  }
  
  void _navigateToHome() {
    _navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomePage(
          isDarkMode: _isDarkMode,
          toggleTheme: _toggleTheme,
        ),
      ),
    );
  }

  Future<void> initializeDeepLinks() async {
    _appLinks = AppLinks();

    // Handle deep links when the app is already running
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Got URI in stream: $uri');
      _handleDeepLink(uri);
    });

    // Handle initial deep link if the app is started by a deep link
    if (!_initialURILinkHandled) {
      final initialURI = await _appLinks.getInitialAppLink();
      if (initialURI != null) {
        debugPrint('Got initial URI: $initialURI');
        _handleDeepLink(initialURI);
      }
      _initialURILinkHandled = true;
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Handling deep link: $uri');
    
    // Check if this is our app's scheme
    if (uri.scheme == 'manan') {
      debugPrint('Detected our app scheme: manan://');
      
      // Try to extract auth info from the URI
      final String? accessToken = uri.queryParameters['access_token'];
      final String? refreshToken = uri.queryParameters['refresh_token'];
      
      if (accessToken != null) {
        debugPrint('Found access token in deep link');
        // If we have tokens, we can try to set the session
        supabase.auth.setSession(accessToken);
        
        // Navigate to home screen after successful authentication
        _navigateToHome();
      } else {
        // No access token found, but we might have auth code in the path
        debugPrint('No access token found in URI, checking for other auth parameters');
        
        // Check if this is a successful verification
        if (uri.path.contains('auth-callback') && !uri.toString().contains('error=')) {
          // This might be a successful verification, check if we're authenticated
          Future.delayed(const Duration(seconds: 1), () async {
            final session = supabase.auth.currentSession;
            if (session != null) {
              _navigateToHome();
            }
          });
        }
      }
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = _isDarkMode ? ThemeData.dark() : ThemeData.light();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'मनन Mental Health App',
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.urbanistTextTheme(baseTheme.textTheme),
      ),
      home: Builder(
        builder:
            (context) => SignInPage(
              onSignInSuccess: () {
                _navigateToHome();
              },
            ),
      ),
    );
  }
}
