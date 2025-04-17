import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/link_service.dart';
import 'package:google_fonts/google_fonts.dart';

// Error logging and reporting
void logError(String error, StackTrace? stackTrace) {
  debugPrint('Error: $error');
  if (stackTrace != null) {
    debugPrint('Stack trace: $stackTrace');
  }
}

Future<void> main() async {
  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logError(details.exceptionAsString(), details.stack);
  };

  // Catch async errors that aren't caught by the Flutter framework
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Initialize settings
    final appSettings = AppSettings();
    await appSettings.loadSettings();

    // Pre-initialize link service to avoid delays on first use
    final linkService = LinkService();
    await linkService.getLinks();

    runApp(
      ChangeNotifierProvider.value(
        value: appSettings,
        child: const LinkHodlApp(),
      ),
    );
  }, (error, stack) {
    logError(error.toString(), stack);
  });
}

class LinkHodlApp extends StatelessWidget {
  const LinkHodlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'LinkHoDL',
          debugShowCheckedModeBanner: false,
          theme: settings.getThemeData(),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.link_rounded,
                  size: 80,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _animation,
              child: Text(
                'LinkHoDL',
                style: GoogleFonts.pacifico(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// User Profile model for the app
class UserProfile {
  final String name;
  final String? email;
  final String? avatarUrl;
  final DateTime joinDate;

  UserProfile({
    required this.name,
    this.email,
    this.avatarUrl,
    required this.joinDate,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    DateTime? joinDate,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinDate: joinDate ?? this.joinDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'joinDate': joinDate.millisecondsSinceEpoch,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'],
      email: map['email'],
      avatarUrl: map['avatarUrl'],
      joinDate: DateTime.fromMillisecondsSinceEpoch(map['joinDate']),
    );
  }

  factory UserProfile.defaultProfile() {
    return UserProfile(
      name: 'User',
      joinDate: DateTime.now(),
    );
  }
}
