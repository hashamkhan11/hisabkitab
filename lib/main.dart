import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hisabshare/widgets/add_category.dart';
import 'package:hisabshare/screens/contact_detail.dart';
import 'package:hisabshare/services/push_notification_service.dart';
import 'package:hisabshare/screens/welcome.dart';
import 'package:hisabshare/providers/current_user_provider.dart';
import 'package:hisabshare/providers/contacts_provider.dart';
import 'package:hisabshare/providers/theme_provider.dart';
import 'package:hisabshare/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runZonedGuarded(
    () => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CurrentUserProvider()),
          ChangeNotifierProvider(create: (_) => ContactsProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MyApp(),
      ),
    ),
    (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );

  // Deliberately not awaited and started after runApp(): this involves a
  // native permission dialog plus a network round-trip to fetch an FCM
  // token, neither of which should delay the first frame - especially on a
  // slow connection where getToken() can take a long time to resolve.
  unawaited(PushNotificationService.initialize());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    // A cold start straight into a deep link (e.g. tapping a ledger-invite
    // link before ever opening the app) lands here with no page underneath
    // it and no signed-in/verified session. Rendering the destination
    // directly in that state used to leave the screen unable to load its
    // data and unable to pop anywhere, which showed up as a black screen.
    // Bounce those cases through the normal auth-gated home route instead.
    redirect: (context, state) {
      final isContactRoute = state.matchedLocation.startsWith('/contact/');
      if (!isContactRoute) return null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !user.emailVerified) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HisabShareApp(),
      ),

  GoRoute(
  path: '/contact/:contactId/:contactName',
  builder: (context, state) {
    final categoryId = state.uri.queryParameters['categoryId'];
    final contactId = state.pathParameters['contactId']!;
    final contactName = Uri.decodeComponent(state.pathParameters['contactName']!);
    final senderUserId = state.uri.queryParameters['senderId'];

    return ContactDetailPage(
      categoryId: categoryId ?? '',
      contactId: contactId,
      contactName: contactName,
      isSharedView: senderUserId != null && senderUserId.isNotEmpty,
      sharedUserId: senderUserId,
    );
  },
),
GoRoute(
      path: '/addCategory',
      builder: (context, state) => AddCategorySheet(),
    ),

    ],
  );
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarIconBrightness:
              themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          title: 'HisabShare App',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.mode,
        );
      },
    );
  }
}


