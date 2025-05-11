import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'homepage.dart';
import 'signin.dart';
import 'permissions_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set the status bar color to light green
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.lightGreen[100],
      statusBarIconBrightness: Brightness.dark, // For dark icons
    ),
  );
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Get credentials from .env file
  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
  
  // Check if credentials are available
  if (url == null || anonKey == null) {
    // In a real app, you might want to show a user-friendly error
    // or use dummy values for development
    debugPrint('ERROR: Missing Supabase credentials in .env file!');
    debugPrint('Make sure .env file exists with SUPABASE_URL and SUPABASE_ANON_KEY');
    return; // This will exit the app initialization
  }
  
  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
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
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    initializeDeepLinks();
    // We'll check permissions first, then auth status
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

  // Navigate to sign in after permissions
  void _navigateToSignIn() {
    _navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (context) => SignInPage(
          onSignInSuccess: () {
            _navigateToHome();
          },
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

  // Handle permission flow completion
  void _onPermissionsGranted() {
    setState(() {
      _permissionsChecked = true;
    });
    // After permissions are granted, proceed with auth flow
    _checkAndNavigateToHome();
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
        builder: (context) {
          // First check if we've gone through permissions flow
          if (!_permissionsChecked) {
            return PermissionsScreen(onPermissionsGranted: _onPermissionsGranted);
          }
          
          // If permissions are checked, proceed with normal auth flow
          return SignInPage(
            onSignInSuccess: () {
              _navigateToHome();
            },
          );
        },
      ),
    );
  }
}
