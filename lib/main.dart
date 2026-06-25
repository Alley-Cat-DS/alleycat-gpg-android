import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/home_screen.dart';
import 'services/key_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait + landscape both fine, but lock to portrait for SMS use case
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize key storage
  await KeyService.instance.init();

  runApp(const AlleyCatApp());
}

class AlleyCatApp extends StatelessWidget {
  const AlleyCatApp({super.key});

  static const _seedColor = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Use device dynamic color if available (Android 12+), else seed color
        final darkScheme = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'AlleyCat GPG',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            fontFamily: 'Roboto',
            appBarTheme: AppBarTheme(
              backgroundColor: darkScheme.surface,
              foregroundColor: darkScheme.onSurface,
              elevation: 0,
              scrolledUnderElevation: 1,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: darkScheme.surface,
              indicatorColor: darkScheme.primaryContainer,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
            cardTheme: CardTheme(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: darkScheme.outlineVariant,
                  width: 1,
                ),
              ),
              color: darkScheme.surfaceContainerLow,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: darkScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: darkScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
