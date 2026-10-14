import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/caixa_cache.dart';
import '../services/cartoes_cache.dart';
import '../services/contas_cache.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../services/sessao_store.dart';
import '../services/token_service.dart';

class AuthProvider with ChangeNotifier {
  static const USER_KEY = SessaoStore.chaveUser;
  static const ID_LOJAS_KEY = SessaoStore.chaveIdLojas;

  /// Valor de [user] para quem entrou pelo link. Não é CNPJ — e o getter
  /// [cnpj] devolve vazio para ele, que é o correto: não sabemos o CNPJ.
  static const _marcadorToken = 'acesso-por-link';

  List<int> _idLojas = [];
  String? _user;
  bool _isAuthenticated = false;
  bool _carregando = true;
  String? _erroLogin;

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

  /// A sessão gravada no dispositivo ainda está sendo lida?
  ///
  /// Começa em `true` e é a razão de a `GuardaSessao` mostrar uma espera antes
  /// de decidir. A leitura é assíncrona e o app já está desenhando: sem este
  /// estado, uma tela interna aberta por recarregamento montava com a sessão
  /// ainda vazia, disparava as requisições com `id_cliente = 0` e só depois
  /// recebia o aviso de que havia sessão.
  bool get sessaoCarregando => _carregando;

  /// O `id_cliente` da sessão, 0 quando não há.
  int get idCliente => _idLojas.isEmpty ? 0 : _idLojas.first;

  /// Autenticado **e** com loja. É o que libera navegação e escrita.
  ///
  /// As duas condições são separadas de propósito: [isAuthenticated] sozinho já
  /// chegou a ser `true` com a lista de lojas vazia, e aí todo o app operava no
  /// cliente 0.
  bool get sessaoValida => _isAuthenticated && idCliente > 0;

  /// Por que o último login falhou, quando há algo melhor a dizer do que
  /// "usuário ou senha inválidos" — hoje, só o usuário sem loja vinculada.
  String? get erroLogin => _erroLogin;

  final ApiService _apiService = ApiService();
  final _logger = LoggerService();

  AuthProvider() {
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    try {
      final sessao = await SessaoStore.ler();

      if (sessao != null) {
        _aplicarSessao(sessao.user, sessao.idLojas);
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'AuthProvider._loadUserFromPrefs',
        e,
        stackTrace: stackTrace,
      );
      // Não relança o erro para não impedir o app de iniciar
    } finally {
      // Sempre, inclusive na falha: travado em "carregando", o app ficaria na
      // espera da `GuardaSessao` para sempre.
      _carregando = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password, bool rememberMe) async {
    _erroLogin = null;

    try {
      final response = await _apiService.login(username, password);
      if (response['success']) {
        final ids = SessaoStore.lojasValidas(
          ((response['data'] as List?) ?? const []).map(
            (i) => int.tryParse(i.toString()) ?? 0,
          ),
        );

        // Credencial certa e nenhuma loja utilizável não é sessão: era por aqui
        // que um `data: [0]` (ou uma lista vazia) autenticava o usuário e
        // deixava o app escrevendo no cliente 0.
        if (ids.isEmpty) {
          _erroLogin =
              'Usuário sem loja vinculada. Procure o suporte para liberar o acesso.';
          await _logger.logError(
            'AuthProvider.login',
            Exception('Login sem loja válida'),
            additionalInfo: {'username': username, 'data': response['data']},
          );
          notifyListeners();
          return false;
        }

        _aplicarSessao(username, ids);

        try {
          await SessaoStore.gravar(
            user: username,
            idLojas: ids,
            lembrar: rememberMe,
          );
        } catch (e, stackTrace) {
          await _logger.logError(
            'AuthProvider.login.savePreferences',
            e,
            stackTrace: stackTrace,
          );
          // Continua mesmo se falhar ao salvar as preferências
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

  Future<void> logout() => _encerrar();

  /// Encerra uma sessão que não pode operar — sem loja, ou já expirada.
  ///
  /// Mesma limpeza do [logout]; o que muda é quem chama. É o caminho da
  /// `GuardaSessao`, que a dispara ao encontrar uma tela interna aberta sem
  /// `id_cliente` (o recarregamento do navegador numa rota interna). Separado
  /// para o aviso na tela de login distinguir "você saiu" de "a sessão caiu".
  Future<void> encerrarSessaoInvalida(String origem) async {
    // `logError`, e não `logInfo`: isto é anomalia, e o painel do suporte lista
    // erro por cliente — é lá que a reincidência aparece. O id_cliente da linha
    // sai em 0, que é exatamente o sintoma sendo relatado.
    await _logger.logError(
      'AuthProvider.encerrarSessaoInvalida',
      Exception('Tela aberta sem id_cliente na sessão'),
      additionalInfo: {
        'origem': origem,
        'autenticado': _isAuthenticated,
        'idLojas': _idLojas,
      },
    );
    await _encerrar();
  }

  Future<void> _encerrar() async {
    _user = null;
    _idLojas = [];
    _isAuthenticated = false;
    _erroLogin = null;
    GlobalState().limpar();
    // As listas de contas e de cartões são de uma loja: sobrevivendo ao logout, a
    // sessão seguinte abriria o modal de lançamento oferecendo as contas e os
    // cartões da loja anterior. O mesmo vale para "esta loja usa caixa": herdado,
    // ele mostraria ou esconderia o menu de Caixas pela loja errada.
    ContasCache().limpar();
    CartoesCache().limpar();
    CaixaCache().limpar();

    try {
      await SessaoStore.limpar();
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
      final ids = SessaoStore.lojasValidas(
        await _apiService.loginByToken(token),
      );

      if (ids.isEmpty) return false;

      _aplicarSessao(_marcadorToken, ids);

      // Mantém o acesso no dispositivo, como antes — o que fica gravado é a
      // sessão, nunca o token.
      try {
        await SessaoStore.gravar(
          user: _marcadorToken,
          idLojas: ids,
          lembrar: true,
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

  /// Ponto único que liga a sessão — os três caminhos de entrada (formulário,
  /// link e sessão gravada) passam por aqui para o `GlobalState` nunca ficar
  /// fora de sincronia com o provider.
  void _aplicarSessao(String user, List<int> ids) {
    _user = user;
    _idLojas = ids;
    GlobalState().idLojas = ids;
    GlobalState().cnpj = cnpj;
    _isAuthenticated = true;
    _erroLogin = null;
  }
}
