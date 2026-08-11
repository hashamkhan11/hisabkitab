import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hisabshare/Models/add_category.dart';
import 'package:hisabshare/Models/contact_detail.dart';
import 'package:hisabshare/Models/model.dart';
import 'package:hisabshare/login.dart';
import 'package:hisabshare/notifications.dart';
import 'package:hisabshare/profile.dart';
import 'package:hisabshare/screens/home.dart';
import 'package:hisabshare/services/notification_service.dart';
import 'package:hisabshare/services/push_notification_service.dart';
import 'package:hisabshare/welcome.dart';
import 'package:hisabshare/Models/contact_detail.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
 await PushNotificationService.initialize(); 
  //await NotificationService().initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
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
      //isSharedView: senderUserId.isNotEmpty,
       isSharedView: senderUserId != null && senderUserId.isNotEmpty,
     // sharedUserId: senderUserId ?? '',
       sharedUserId: senderUserId ?? '',
        
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
   /* SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );*/
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      //statusBarColor: Colors.grey.shade100,
      statusBarIconBrightness: Brightness.dark
  ));
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      title: 'HisabShare App',
    );
  }
}


