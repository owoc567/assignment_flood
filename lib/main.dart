import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:assignment_flood/screens/users/reset_password.dart';
import 'package:assignment_flood/screens/users/sign_in.dart';

const String supabaseUrl = 'https://supzirushfgvowladjql.supabase.co';
const String supabaseKey = 'sb_secret_8KYYYt-a_yxO9Zr2DmGfPw_A5M-nlKu';


final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

// Create this early so the app can catch the first link.
final AppLinks appLinks = AppLinks();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey
  );

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;

  bool _resetPageOpened = false;

  @override
  void initState() {
    super.initState();

    // Detect Supabase password-recovery events.
    _authSubscription = Supabase.instance.client.auth
        .onAuthStateChange
        .listen((authState) async {
      debugPrint('Auth event: ${authState.event}');

      if (authState.event ==
          AuthChangeEvent.passwordRecovery) {
        _openResetPasswordPage();
        return;
      }

      if (authState.event == AuthChangeEvent.userUpdated) {
        final user = authState.session?.user ??
            Supabase.instance.client.auth.currentUser;

        if (user != null && user.email != null) {
          try {
            await Supabase.instance.client
                .from('profiles')
                .update({
              'email': user.email!.trim().toLowerCase(),
            })
                .eq('id', user.id);

            debugPrint(
              'Profile email synchronized: ${user.email}',
            );
          } catch (error) {
            debugPrint(
              'Unable to synchronize profile email: $error',
            );
          }
        }
      }
    });

    // Detect the actual mobile deep link.
    _linkSubscription = appLinks.uriLinkStream.listen(
          (uri) {
        debugPrint('Incoming app link: $uri');

        if (uri.scheme != 'io.supabase.flutter') {
          return;
        }

        if (uri.host == 'reset-callback') {
          _openResetPasswordPage();
          return;
        }

        if (uri.host == 'email-change-callback') {
          Future.delayed(const Duration(seconds: 1), () async {
            final user =
                Supabase.instance.client.auth.currentUser;

            if (user != null && user.email != null) {
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({
                  'email': user.email!.trim().toLowerCase(),
                })
                    .eq('id', user.id);

                debugPrint(
                  'Confirmed email synchronized: ${user.email}',
                );
              } catch (error) {
                debugPrint(
                  'Email synchronization failed: $error',
                );
              }
            }
          });
        }
      },
      onError: (error) {
        debugPrint('App link error: $error');
      },
    );
  }

  void _openResetPasswordPage() {
    if (_resetPageOpened) return;

    _resetPageOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        _resetPageOpened = false;
        return;
      }

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ResetPasswordPage(),
        ),
            (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Mobile Wallpaper.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(child: SizedBox()),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignIn(),
                      ),
                    );
                  },
                  child: const Text('Get Started'),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}