import 'package:flutter/material.dart';

import 'data/database.dart';
import 'services/notification_service.dart';
import 'state/app_controller.dart';
import 'screens/home_screen.dart';

class MoneyTrackerApp extends StatefulWidget {
  const MoneyTrackerApp({
    super.key,
    required this.database,
    required this.notifications,
  });

  final AppDatabase database;
  final NotificationService notifications;

  @override
  State<MoneyTrackerApp> createState() => _MoneyTrackerAppState();
}

class _MoneyTrackerAppState extends State<MoneyTrackerApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(
      database: widget.database,
      notifications: widget.notifications,
    );
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    widget.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Money Tracker',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.deepOrange,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF7F7F7),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.deepOrange,
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          home: HomeScreen(controller: controller),
        );
      },
    );
  }
}