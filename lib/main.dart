import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/feed_service.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to init Firebase. If google-services.json / options are missing,
  // the app still runs in local mode.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase not configured yet – running in local mode. $e');
  }

  final auth = AuthService();
  await auth.initialize();
  await DataService().initialize();

  // Push notifications (safe even if Firebase is not fully set up)
  await NotificationService().initialize();

  runApp(Donut4uApp(auth: auth));
}

class Donut4uApp extends StatelessWidget {
  final AuthService auth;
  const Donut4uApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => FeedService()..initialize()),
      ],
      child: MaterialApp(
        title: 'donut4u',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF6B6B),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
