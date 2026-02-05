import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  String? _role;
  String? _displayName;

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get role => _role;
  String? get displayName => _displayName;
  
  // Check apakah user adalah pemilik toko
  bool get isPemilikToko => _role == 'pemilik_toko';
  
  // Check apakah user adalah kasir
  bool get isKasir => _role == 'kasir';

  AuthProvider() {
    _loadLoginState();
  }

  // Load state login dari SharedPreferences
  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _username = prefs.getString('username');
    _role = prefs.getString('role');
    _displayName = prefs.getString('displayName');
    notifyListeners();
  }

  // Login dengan validasi user dan role
  Future<bool> login(String username, String password) async {
    final user = DefaultUsers.authenticate(username, password);
    
    if (user != null) {
      _isLoggedIn = true;
      _username = user.username;
      _role = user.role;
      _displayName = user.displayName;

      // Simpan state login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', user.username);
      await prefs.setString('role', user.role);
      await prefs.setString('displayName', user.displayName);

      notifyListeners();
      return true;
    }
    return false;
  }

  // Logout
  Future<void> logout() async {
    _isLoggedIn = false;
    _username = null;
    _role = null;
    _displayName = null;

    // Hapus state login
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('username');
    await prefs.remove('role');
    await prefs.remove('displayName');

    notifyListeners();
  }
}