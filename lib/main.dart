import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'theme/app_theme.dart';
import 'provider/auth_provider.dart';
import 'provider/theme_provider.dart';
import 'provider/task_provider.dart';
import 'provider/admin_provider.dart';
import 'provider/chat_provider.dart';
import 'provider/notification_provider.dart';
import 'services/socket_service.dart';
import 'services/local_notification_service.dart';
import 'services/workmanager_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables. If file doesn't exist, it might fail, so wrap in try-catch
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file. Using default endpoints.");
  }

  // Initialize OS-level notification service (for background/locked-screen notifications)
  await LocalNotificationService().initialize();
  
  // Initialize and register Workmanager for background tasks (when app is off)
  await WorkmanagerService.initialize();
  await WorkmanagerService.registerPeriodicTask();
  
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        Provider(create: (_) => SocketService()),
      ],

      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Task Management OS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode, 
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
