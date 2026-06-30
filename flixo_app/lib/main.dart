import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:media_kit/media_kit.dart';
import 'services/local_streaming_proxy.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'navigation/main_nav.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'utils/globals.dart';

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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F0F0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const FlixoApp());
}

class FlixoApp extends StatelessWidget {
  const FlixoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLIXO',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
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
