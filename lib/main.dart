import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  await database.open();

  final notifications = NotificationService();
  try {
    await notifications.initialize();
    await notifications.requestPermissions();
  } catch (e, st) {
    debugPrint('[main] notification init failed: $e\n$st');
  }

  runApp(
    MoneyTrackerApp(
      database: database,
      notifications: notifications,
    ),
  );
}