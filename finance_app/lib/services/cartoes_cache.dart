import '../models/cartao.dart';
import 'api_service.dart';

/// Lista de cartões de crédito da loja, carregada uma vez por sessão.
///
/// Gêmeo do [ContasCache], e pelo mesmo motivo: o modal de lançamento do cartão
/// já consulta categorias e subcategorias **a cada abertura**, e o seletor de
/// cartão precisa da lista toda vez — inclusive para decidir se aparece, já que
/// com um cartão só não há escolha a fazer. Consultar ali faria uma terceira
/// requisição por abertura, para um dado que muda muito menos que o lançamento.
///
/// A lista é curta (uma loja tem punhado de cartões) e só muda na página de
/// Cartões, que invalida o cache ao criar, editar ou apagar.
///
/// Singleton simples, no estilo do [GlobalState]: não é Provider porque ninguém
/// precisa reconstruir a árvore quando a lista troca.
class CartoesCache {
  static final CartoesCache _instance = CartoesCache._internal();

  factory CartoesCache() => _instance;

  CartoesCache._internal();

  final ApiService _api = ApiService();

  List<Cartao>? _cartoes;

  /// Pedido em andamento. Dois modais abertos em sequência rápida compartilham a
  /// mesma requisição em vez de disparar duas.
  Future<List<Cartao>>? _emVoo;

  /// Os cartões da loja, do cache quando já carregados.
  ///
  /// Falha de rede **não** é guardada: devolve lista vazia e deixa o cache vazio,
  /// para a tentativa seguinte tentar de novo.
  Future<List<Cartao>> obter({bool recarregar = false}) async {
    if (!recarregar && _cartoes != null) return _cartoes!;

    if (_emVoo != null) return _emVoo!;

    final pedido = _api.listCartoes();
    _emVoo = pedido;

    try {
      final cartoes = await pedido;
      _cartoes = cartoes;
      return cartoes;
    } catch (_) {
      // O ApiService já registrou o erro no log remoto com endpoint e corpo.
      return const [];
    } finally {
      _emVoo = null;
    }
  }

  /// O que o seletor de lançamento oferece: cartão arquivado não recebe
  /// lançamento novo.
  ///
  /// O arquivado continua existindo e aparecendo na página de Cartões — e um
  /// lançamento antigo nele não é alterado.
  List<Cartao> get ativos =>
      (_cartoes ?? const <Cartao>[]).where((c) => c.ativado).toList();

  /// Já carregado? Quem desenha usa isto para não piscar um seletor vazio antes
  /// da primeira resposta.
  bool get carregado => _cartoes != null;

  /// O cartão pelo id, ou `null` — para a tela de movimentos resolver o cartão da
  /// rota sem uma consulta própria.
  Cartao? porId(int id) {
    for (final c in _cartoes ?? const <Cartao>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Marca o cache como sujo. Chamado pela página de Cartões depois de criar,
  /// editar ou apagar — a próxima leitura busca de novo.
  void invalidar() => _cartoes = null;

  /// Esvazia no logout: a lista é de uma loja, e a sessão seguinte pode ser de
  /// outra.
  void limpar() {
    _cartoes = null;
    _emVoo = null;
  }
}
