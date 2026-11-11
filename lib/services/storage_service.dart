import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mikrotik_models.dart';

class StorageService {
  static const String _profilesKey = 'fnet_router_profiles';
  static const String _activeProfileKey = 'fnet_active_profile_id';
  static const String _masterAuthKey = 'fnet_master_auth';
  static const String _sessionKey = 'fnet_master_session';
  static const String _themeKey = 'fnet_theme';
  static const String _themeColorKey = 'fnet_theme_color';
  static const String _rememberMeKey = 'fnet_remember_me';
  static const String _savedUsernameKey = 'fnet_saved_username';
  static const String _savedPasswordKey = 'fnet_saved_password';
  static const String _pollingIntervalKey = 'fnet_polling_interval';

  static final RouterProfile defaultProfile = RouterProfile(
    id: 'default-profile',
    name: 'mikrotik01',
    host: '192.168.88.1',
    port: 80,
    useHttps: false,
    username: 'admin',
    password: '',
    rememberPassword: true,
    timeoutSeconds: 8,
  );

  static const MasterAuth defaultMasterAuth = MasterAuth(
    username: 'superadmin',
    password: 'ihwan',
  );

  // Router Profiles
  static Future<List<RouterProfile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) {
      return [defaultProfile];
    }
    try {
      final List<dynamic> list = jsonDecode(raw);
      if (list.isEmpty) return [defaultProfile];
      return list.map((item) => RouterProfile.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [defaultProfile];
    }
  }

  static Future<List<RouterProfile>> saveProfile(RouterProfile profile) async {
    final profiles = await getProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    List<RouterProfile> updated;
    if (index >= 0) {
      updated = List.from(profiles);
      updated[index] = profile;
    } else {
      updated = [...profiles, profile];
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilesKey, jsonEncode(updated.map((p) => p.toJson()).toList()));
    return updated;
  }

  static Future<List<RouterProfile>> deleteProfile(String id) async {
    final profiles = await getProfiles();
    final updated = profiles.where((p) => p.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilesKey, jsonEncode(updated.map((p) => p.toJson()).toList()));
    return updated;
  }

  // Active Profile ID
  static Future<String> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey) ?? 'default-profile';
  }

  static Future<void> setActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, id);
  }

  // Master Auth
  static Future<MasterAuth> getMasterAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_masterAuthKey);
    if (raw == null || raw.isEmpty) {
      return defaultMasterAuth;
    }
    try {
      return MasterAuth.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return defaultMasterAuth;
    }
  }

  static Future<void> saveMasterAuth(MasterAuth auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_masterAuthKey, jsonEncode(auth.toJson()));
  }

  // Session
  static Future<bool> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionKey) ?? false;
  }

  static Future<void> setSession(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, isLoggedIn);
  }

  // Theme
  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'dark';
  }

  static Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  // Theme Color (Seed)
  static Future<String> getThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeColorKey) ?? 'blue';
  }

  static Future<void> setThemeColor(String colorKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, colorKey);
  }

  // Remember Me Credentials
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  static Future<Map<String, String>?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final isRemembered = prefs.getBool(_rememberMeKey) ?? false;
    if (!isRemembered) return null;
    final u = prefs.getString(_savedUsernameKey) ?? '';
    final p = prefs.getString(_savedPasswordKey) ?? '';
    return {'username': u, 'password': p};
  }

  static Future<void> saveRememberedCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, true);
    await prefs.setString(_savedUsernameKey, username);
    await prefs.setString(_savedPasswordKey, password);
  }

  static Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, false);
    await prefs.remove(_savedUsernameKey);
    await prefs.remove(_savedPasswordKey);
  }

  // Polling Interval in seconds (default: 2)
  static Future<int> getPollingInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pollingIntervalKey) ?? 2;
  }

  static Future<void> setPollingInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pollingIntervalKey, seconds);
  }
}
