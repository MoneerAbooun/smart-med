import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/app/main_shell.dart';
import 'package:smart_med/features/auth/auth.dart';
import 'package:smart_med/features/profile/profile.dart';

class AuthenticatedAppGate extends StatefulWidget {
  const AuthenticatedAppGate({
    super.key,
    required this.user,
    required this.cameras,
    required this.isDark,
    required this.onThemeChanged,
  });

  final User user;
  final List<CameraDescription> cameras;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<AuthenticatedAppGate> createState() => _AuthenticatedAppGateState();
}

class _AuthenticatedAppGateState extends State<AuthenticatedAppGate> {
  late Future<UserProfileRecord> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAppGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.uid != widget.user.uid) {
      _bootstrapFuture = _bootstrap();
    }
  }

  Future<void> _retryBootstrap() async {
    setState(() {
      _bootstrapFuture = _bootstrap();
    });
  }

  Future<void> _signOut() async {
    await authRepository.signOut();
  }

  Future<UserProfileRecord> _bootstrap() {
    return authUserFlowRepository.ensureProfileForUser(widget.user);
  }

  String _bootstrapErrorMessage(Object error) {
    if (error is ProfileRepositoryException) {
      return error.message;
    }

    if (error is AuthFlowException) {
      return error.message;
    }

    return 'Retry to create or repair the user document, or sign out to try again later.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfileRecord>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your profile...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'We could not finish loading your Firestore profile.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _bootstrapErrorMessage(snapshot.error!),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _retryBootstrap,
                          child: const Text('Retry'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          child: const Text('Sign Out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return MainShell(
          cameras: widget.cameras,
          isDark: widget.isDark,
          onThemeChanged: widget.onThemeChanged,
        );
      },
    );
  }
}
