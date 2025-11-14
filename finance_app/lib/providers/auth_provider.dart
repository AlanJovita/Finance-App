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
        await _logger.logInfo(
          'AuthProvider._loadUserFromPrefs',
          'Usuário carregado das preferências: $_user',
        );
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
      await _logger.logInfo(
        'AuthProvider.login',
        'Tentativa de login para usuário: $username',
      );

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
            await _logger.logInfo(
              'AuthProvider.login',
              'Credenciais salvas para lembrar depois',
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

        await _logger.logInfo(
          'AuthProvider.login',
          'Login bem-sucedido para usuário: $username',
        );
        notifyListeners();
        return true;
      }

      await _logger.logWarning(
        'AuthProvider.login',
        'Login falhou - resposta success=false para usuário: $username',
      );
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
      final userBeforeLogout = _user;

      _user = null;
      _idLojas = [];
      GlobalState().idLojas = [];
      _isAuthenticated = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(USER_KEY);
      await prefs.remove(ID_LOJAS_KEY);

      await _logger.logInfo(
        'AuthProvider.logout',
        'Logout realizado para usuário: $userBeforeLogout',
      );
      notifyListeners();
    } catch (e, stackTrace) {
      await _logger.logError('AuthProvider.logout', e, stackTrace: stackTrace);
      // Não relança o erro para garantir que o estado seja limpo
      rethrow;
    }
  }
}
