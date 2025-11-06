import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';

class AuthProvider with ChangeNotifier {
  static const USER_KEY = 'auth_user';
  static const ID_LOJAS_KEY = 'id_lojas';

  List<int> _idLojas = [];
  String? _user;
  bool _isAuthenticated = false;

  List<int> get idLojas => _idLojas;
  String? get user => _user;
  bool get isAuthenticated => _isAuthenticated;

  final ApiService _apiService = ApiService();

  AuthProvider() {
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _user = prefs.getString(USER_KEY);
    final idLojasString = prefs.getStringList(ID_LOJAS_KEY);

    if (_user != null && idLojasString != null) {
      _idLojas = idLojasString.map((i) => int.parse(i)).toList();
      GlobalState().idLojas = _idLojas;
      _isAuthenticated = true;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password, bool rememberMe) async {
    try {
      final response = await _apiService.login(username, password);
      if (response['success']) {
        _user = username;
        _idLojas = List<int>.from(response['data']);
        GlobalState().idLojas = _idLojas;
        _isAuthenticated = true;

        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(USER_KEY, username);
          await prefs.setStringList(
            ID_LOJAS_KEY,
            _idLojas.map((i) => i.toString()).toList(),
          );
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _idLojas = [];
    GlobalState().idLojas = [];
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(USER_KEY);
    await prefs.remove(ID_LOJAS_KEY);

    notifyListeners();
  }
}
