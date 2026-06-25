import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'compose_screen.dart';
import 'decrypt_screen.dart';
import 'keys_screen.dart';
import 'file_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final _screens = const [
    ComposeScreen(),
    DecryptScreen(),
    FileScreen(),
    KeysScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Handle shared text from SMS app (intent-filter in manifest)
    _handleSharedText();
  }

  Future<void> _handleSharedText() async {
    // If app was launched via "Share" from another app, switch to decrypt tab
    final intent = ModalRoute.of(context);
    if (intent != null) {
      // Handled in DecryptScreen via shared_preferences flag
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'Compose',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_open_outlined),
              selectedIcon: Icon(Icons.lock_open),
              label: 'Decrypt',
            ),
            NavigationDestination(
              icon: Icon(Icons.attach_file_outlined),
              selectedIcon: Icon(Icons.attach_file),
              label: 'Files',
            ),
            NavigationDestination(
              icon: Icon(Icons.key_outlined),
              selectedIcon: Icon(Icons.key),
              label: 'Keys',
            ),
          ],
        ),
      ),
    );
  }
}
