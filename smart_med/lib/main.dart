import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:smart_med/login.dart';
import 'app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med/services/notification_service.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('isDark') ?? false;

  cameras = await availableCameras();

  await NotificationService.init();

  runApp(
    MainApp(
      cameras: cameras,
      initialThemeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    ),
  );
}

class MainApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ThemeMode initialThemeMode;
  final Stream<User?>? authStateChanges;
  final User? initialUser;
  final Future<void> Function(User? user)? syncNotificationsForUser;

  const MainApp({
    super.key,
    required this.cameras,
    required this.initialThemeMode,
    this.authStateChanges,
    this.initialUser,
    this.syncNotificationsForUser,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late ThemeMode _themeMode;
  bool _notificationPermissionRequested = false;
  StreamSubscription<User?>? _authSubscription;
  String? _lastSyncedUserId;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermissionOnce();
    });

    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _syncNotificationsForUser(_currentUser);

    _authSubscription = _authStateChanges.listen((user) {
      _syncNotificationsForUser(user);
    });
  }

  User? get _currentUser {
    if (widget.authStateChanges != null) {
      return widget.initialUser;
    }

    return FirebaseAuth.instance.currentUser;
  }

  Stream<User?> get _authStateChanges {
    return widget.authStateChanges ?? FirebaseAuth.instance.authStateChanges();
  }

  Future<void> _syncNotificationsForUser(User? user) async {
    final String? userId = user?.uid;

    if (userId == _lastSyncedUserId) {
      return;
    }

    _lastSyncedUserId = userId;
    final syncNotificationsForUser = widget.syncNotificationsForUser;

    if (syncNotificationsForUser != null) {
      await syncNotificationsForUser(user);
      return;
    }

    await NotificationService.syncNotificationsForCurrentUser();
  }

  Future<void> _requestNotificationPermissionOnce() async {
    if (_notificationPermissionRequested) return;

    _notificationPermissionRequested = true;
    await NotificationService.requestPermission();
  }

  Future<void> _changeTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: StreamBuilder<User?>(
        stream: _authStateChanges,
        initialData: _currentUser,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return MainScreen(
              cameras: widget.cameras,
              isDark: _themeMode == ThemeMode.dark,
              onThemeChanged: _changeTheme,
            );
          } else {
            return Login(cameras: widget.cameras);
          }
        },
      ),
    );
  }
}
