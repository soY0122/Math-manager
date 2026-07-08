import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Print Firebase configuration to the browser console for deployment debugging
  try {
    final appOptions = Firebase.app().options;
    print('DEBUG FIREBASE CONFIG:');
    print('projectId: ${appOptions.projectId}');
    print('apiKey: ${appOptions.apiKey}');
    print('authDomain: ${appOptions.authDomain}');
  } catch (e) {
    print('DEBUG FIREBASE CONFIG ERROR: $e');
  }

  // Initialize Korean date formatting
  await initializeDateFormatting('ko_KR', null);

  runApp(
    const ProviderScope(
      child: MathManagerApp(),
    ),
  );
}

class MathManagerApp extends ConsumerWidget {
  const MathManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Math Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}