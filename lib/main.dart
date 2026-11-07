import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/storage_service.dart';
import 'theme/fnet_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isLoggedIn = await StorageService.getSession();
  final savedTheme = await StorageService.getTheme();

  runApp(MikrotikManagerApp(
    initialLoggedIn: isLoggedIn,
    initialTheme: savedTheme,
  ));
}

typedef FNetApp = MikrotikManagerApp;

class MikrotikManagerApp extends StatefulWidget {
  final bool initialLoggedIn;
  final String initialTheme;

  const MikrotikManagerApp({
    super.key,
    this.initialLoggedIn = false,
    this.initialTheme = 'system',
  });

  @override
  State<MikrotikManagerApp> createState() => _MikrotikManagerAppState();
}

class _MikrotikManagerAppState extends State<MikrotikManagerApp> {
  late bool _isLoggedIn;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialLoggedIn;
    _isDark = widget.initialTheme != 'light';
    _applySystemOverlay();
  }

  void _applySystemOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: _isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void _toggleTheme() async {
    setState(() {
      _isDark = !_isDark;
    });
    await StorageService.setTheme(_isDark ? 'dark' : 'light');
    _applySystemOverlay();
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() async {
    await StorageService.setSession(false);
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mikrotik Manager',
      debugShowCheckedModeBanner: false,
      theme: FNetTheme.lightTheme(),
      darkTheme: FNetTheme.darkTheme(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: _isLoggedIn
          ? MainNavigationScreen(
              onToggleTheme: _toggleTheme,
              isDark: _isDark,
              onLogout: _handleLogout,
            )
          : LoginScreen(
              onToggleTheme: _toggleTheme,
              isDark: _isDark,
              onLoginSuccess: _handleLoginSuccess,
            ),
    );
  }
}
