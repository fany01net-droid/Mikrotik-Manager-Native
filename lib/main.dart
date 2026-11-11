import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'theme/fnet_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isLoggedIn = await StorageService.getSession();
  final savedTheme = await StorageService.getTheme();
  final savedThemeColor = await StorageService.getThemeColor();

  runApp(MikrotikManagerApp(
    initialLoggedIn: isLoggedIn,
    initialTheme: savedTheme,
    initialThemeColor: savedThemeColor,
  ));
}

typedef FNetApp = MikrotikManagerApp;

class MikrotikManagerApp extends StatefulWidget {
  final bool initialLoggedIn;
  final String initialTheme;
  final String initialThemeColor;

  const MikrotikManagerApp({
    super.key,
    this.initialLoggedIn = false,
    this.initialTheme = 'system',
    this.initialThemeColor = 'blue',
  });

  @override
  State<MikrotikManagerApp> createState() => _MikrotikManagerAppState();
}

class _MikrotikManagerAppState extends State<MikrotikManagerApp> {
  late bool _isLoggedIn;
  late bool _isDark;
  late String _currentColor;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialLoggedIn;
    _isDark = widget.initialTheme != 'light';
    _currentColor = widget.initialThemeColor;
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

  void _handleChangeThemeColor(String colorKey) async {
    setState(() {
      _currentColor = colorKey;
    });
    await StorageService.setThemeColor(colorKey);
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
    final seed = FNetTheme.getSeedColor(_currentColor);

    return MaterialApp(
      title: 'Fanny Network',
      debugShowCheckedModeBanner: false,
      theme: FNetTheme.lightTheme(seed),
      darkTheme: FNetTheme.darkTheme(seed),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = child.key != const ValueKey('splash_screen');
          if (isIncoming) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.03),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          } else {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          }
        },
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash_screen'),
                themeColor: _currentColor,
                isDark: _isDark,
                onFinish: () {
                  setState(() {
                    _showSplash = false;
                  });
                },
              )
            : (_isLoggedIn
                ? MainNavigationScreen(
                    key: const ValueKey('main_screen'),
                    onToggleTheme: _toggleTheme,
                    isDark: _isDark,
                    themeColor: _currentColor,
                    onChangeThemeColor: _handleChangeThemeColor,
                    onLogout: _handleLogout,
                  )
                : LoginScreen(
                    key: const ValueKey('login_screen'),
                    onToggleTheme: _toggleTheme,
                    isDark: _isDark,
                    onLoginSuccess: _handleLoginSuccess,
                  )),
      ),
    );
  }
}
