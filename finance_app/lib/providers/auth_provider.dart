import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/contas_cache.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../services/token_service.dart';

class AuthProvider with ChangeNotifier {
  static const USER_KEY = 'auth_user';
  static const ID_LOJAS_KEY = 'id_lojas';

  /// Valor de [user] para quem entrou pelo link. Não é CNPJ — e o getter
  /// [cnpj] devolve vazio para ele, que é o correto: não sabemos o CNPJ.
  static const _marcadorToken = 'acesso-por-link';

  List<int> _idLojas = [];
  String? _user;
  bool _isAuthenticated = false;

  List<int> get idLojas => _idLojas;
  String? get user => _user;

  /// CNPJ do usuário logado, só dígitos.
  ///
  /// Os dois caminhos de login guardam o CNPJ em [user], com formatos
  /// diferentes: por token vira `'CNPJ: 12345678000199'`; pelo formulário é o
  /// `finance_usuario.login`, que é o próprio CNPJ — o login por CNPJ consulta
  /// essa mesma coluna. Ficar só com os dígitos cobre os dois sem o chamador
  /// precisar saber de qual veio.
  String get cnpj => (_user ?? '').replaceAll(RegExp(r'\D'), '');
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
        GlobalState().cnpj = cnpj;
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
        GlobalState().cnpj = cnpj;
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
    _user = null;
    _idLojas = [];
    GlobalState().idLojas = [];
    GlobalState().cnpj = '';
    // A lista de contas é de uma loja: sobrevivendo ao logout, a sessão seguinte
    // abriria o modal de lançamento oferecendo as contas da loja anterior.
    ContasCache().limpar();
    _isAuthenticated = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(USER_KEY);
      await prefs.remove(ID_LOJAS_KEY);
    } catch (e, stackTrace) {
      // Falha ao apagar o disco não pode impedir a saída: o estado em memória
      // já foi limpo acima e o `notifyListeners` abaixo roda de qualquer jeito.
      // Antes, o SharedPreferences estourando deixava o usuário na tela em que
      // estava — a UI nem era avisada, porque tanto o notifyListeners quanto a
      // navegação de quem chamou ficavam depois do ponto da exceção.
      // O custo de não conseguir apagar é o "lembrar-me" sobreviver.
      await _logger.logError('AuthProvider.logout', e, stackTrace: stackTrace);
    }

    notifyListeners();
  }

  /// Entra pelo link de acesso: troca o token pelos ids e autentica.
  ///
  /// O token é opaco — o app não extrai nada dele. Antes era `base64(cnpj)` e
  /// este método decodificava o CNPJ para mandar a `/login/cnpj`; como CNPJ é
  /// público, qualquer um montava o link de qualquer loja.
  ///
  /// Por isso [user] guarda só um marcador aqui: não há CNPJ a guardar, e o
  /// token é credencial — não vai para o SharedPreferences.
  Future<bool> loginByToken(String token) async {
    if (!TokenService.pareceToken(token)) return false;

    try {
      final ids = await _apiService.loginByToken(token);

      if (ids.isEmpty) return false;

      _user = _marcadorToken;
      _idLojas = ids;
      GlobalState().idLojas = _idLojas;
      GlobalState().cnpj = cnpj;
      _isAuthenticated = true;

      // Mantém o acesso no dispositivo, como antes — o que fica gravado é a
      // sessão, nunca o token.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(USER_KEY, _user!);
        await prefs.setStringList(
          ID_LOJAS_KEY,
          _idLojas.map((i) => i.toString()).toList(),
        );
      } catch (e, stackTrace) {
        await _logger.logError(
          'AuthProvider.loginByToken (save prefs)',
          e,
          stackTrace: stackTrace,
        );
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      // Sem o token no log: é a credencial de acesso.
      await _logger.logError(
        'AuthProvider.loginByToken',
        e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
