import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:media_kit/media_kit.dart';
import 'services/local_streaming_proxy.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'navigation/main_nav.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'utils/globals.dart';

import 'package:app_links/app_links.dart';
import 'services/tmdb_service.dart';
import 'screens/movie_detail_screen.dart';
import 'models/movie.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  final bool startProxy = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.android);
  if (startProxy) {
    await LocalStreamingProxy.instance.start();
  }

  usePathUrlStrategy();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize Firebase Analytics
  final analytics = FirebaseAnalytics.instance;
  await analytics.logAppOpen();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F0F0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Graceful Error Boundary Fallback for production builds
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0C0C0D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.error_outline_rounded, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'An unexpected error occurred.',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  };

  runApp(const FlixoApp());
}

class FlixoApp extends StatefulWidget {
  const FlixoApp({super.key});

  @override
  State<FlixoApp> createState() => _FlixoAppState();
}

class _FlixoAppState extends State<FlixoApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) async {
    debugPrint('[DeepLink] Handling deep link: $uri');
    if (uri.path.contains('/movie')) {
      final idStr = uri.queryParameters['id'];
      if (idStr != null) {
        final id = int.tryParse(idStr);
        if (id != null) {
          try {
            final movie = await TmdbService.getMovieById(id);
            if (movie != null && mounted) {
              await Future.delayed(const Duration(milliseconds: 300));
              navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
              );
            }
          } catch (e) {
            debugPrint('[DeepLink] Error resolving movie ID: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieNest',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.contains('/movie/')) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const AuthGate(),
          );
        }
        return null;
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNav();
  }
}
