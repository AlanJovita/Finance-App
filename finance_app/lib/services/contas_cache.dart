import '../models/conta.dart';
import 'api_service.dart';

/// Lista de contas bancárias da loja, carregada uma vez por sessão.
///
/// Existe por causa do modal de lançamento. Ele já consulta categorias e
/// subcategorias **a cada abertura** (`FluxoFormDialog.initState`), e o seletor de
/// conta precisa da lista toda vez — inclusive para decidir se aparece, já que o
/// seletor só existe quando há conta cadastrada. Consultar ali faria uma terceira
/// requisição por abertura, para um dado que muda muito menos que o lançamento.
///
/// A lista é curta (uma loja tem punhado de contas) e só muda na página de Contas,
/// que invalida o cache ao criar, editar ou apagar.
///
/// Singleton simples, no estilo do [GlobalState]: não é Provider porque ninguém
/// precisa reconstruir a árvore quando a lista troca — quem usa pede a lista no
/// momento em que vai desenhar.
class ContasCache {
  static final ContasCache _instance = ContasCache._internal();

  factory ContasCache() => _instance;

  ContasCache._internal();

  final ApiService _api = ApiService();

  List<Conta>? _contas;

  /// Pedido em andamento. Dois modais abertos em sequência rápida (ou a página de
  /// Contas junto com um modal) compartilham a mesma requisição em vez de
  /// disparar duas.
  Future<List<Conta>>? _emVoo;

  /// As contas da loja, do cache quando já carregadas.
  ///
  /// Falha de rede **não** é guardada: devolve lista vazia e deixa o cache vazio,
  /// para a tentativa seguinte tentar de novo. O efeito de falhar é o seletor de
  /// conta não aparecer no modal — o lançamento continua possível, sem conta.
  Future<List<Conta>> obter({bool recarregar = false}) async {
    if (!recarregar && _contas != null) return _contas!;

    if (_emVoo != null) return _emVoo!;

    final pedido = _api.listContas();
    _emVoo = pedido;

    try {
      final contas = await pedido;
      _contas = contas;
      return contas;
    } catch (_) {
      // O ApiService já registrou o erro no log remoto com endpoint e corpo.
      return const [];
    } finally {
      _emVoo = null;
    }
  }

  /// O que o seletor do modal oferece: conta arquivada não entra em lançamento
  /// novo.
  ///
  /// A conta arquivada continua existindo e aparecendo na página de Contas — e um
  /// lançamento antigo que aponte para ela não é alterado.
  List<Conta> get ativas =>
      (_contas ?? const <Conta>[]).where((c) => c.ativado).toList();

  /// Já carregado? Quem desenha usa isto para não piscar um seletor vazio antes
  /// da primeira resposta.
  bool get carregado => _contas != null;

  /// Preenche o cache com uma lista já em mãos, sem ir à rede.
  ///
  /// A página de Contas chama isto depois de carregar os saldos: a resposta de
  /// `/conta/saldos` já traz todos os campos de uma [Conta] (id, descrição,
  /// ativado, imagem, saldo inicial), então buscar a mesma lista de novo em
  /// `/conta/list` na abertura do próximo lançamento seria uma requisição para
  /// obter o que já está na memória.
  void semear(List<Conta> contas) => _contas = contas;

  /// Marca o cache como sujo. Chamado pela página de Contas depois de criar,
  /// editar ou apagar — a próxima leitura busca de novo.
  void invalidar() => _contas = null;

  /// Esvazia no logout: a lista é de uma loja, e a sessão seguinte pode ser de
  /// outra.
  void limpar() {
    _contas = null;
    _emVoo = null;
  }
}
