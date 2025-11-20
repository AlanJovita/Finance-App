import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';

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
  final _logger = LoggerService();

  AuthProvider() {
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _user = prefs.getString(USER_KEY);
      final idLojasString = prefs.getStringList(ID_LOJAS_KEY);

      if (_user != null && idLojasString != null) {
        _idLojas = idLojasString.map((i) => int.parse(i)).toList();
        GlobalState().idLojas = _idLojas;
        _isAuthenticated = true;
      }
      notifyListeners();
    } catch (e, stackTrace) {
      await _logger.logError(
        'AuthProvider._loadUserFromPrefs',
        e,
        stackTrace: stackTrace,
      );
      // Não relança o erro para não impedir o app de iniciar
    }
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
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(USER_KEY, username);
            await prefs.setStringList(
              ID_LOJAS_KEY,
              _idLojas.map((i) => i.toString()).toList(),
            );
          } catch (e, stackTrace) {
            await _logger.logError(
              'AuthProvider.login.savePreferences',
              e,
              stackTrace: stackTrace,
            );
            // Continua mesmo se falhar ao salvar as preferências
          }
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      await _logger.logError(
        'AuthProvider.login',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'username': username, 'rememberMe': rememberMe},
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      _user = null;
      _idLojas = [];
      GlobalState().idLojas = [];
      _isAuthenticated = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(USER_KEY);
      await prefs.remove(ID_LOJAS_KEY);

      notifyListeners();
    } catch (e, stackTrace) {
      await _logger.logError('AuthProvider.logout', e, stackTrace: stackTrace);
      // Não relança o erro para garantir que o estado seja limpo
      rethrow;
    }
  }
}
