import 'api_service.dart';

/// A loja usa caixa? Uma resposta por sessão.
///
/// Existe porque a pergunta tem **dois leitores em telas diferentes**: o painel,
/// que esconde o resumo do caixa e o atalho, e o menu lateral, que esconde o item
/// "Caixas". Sem o cache, abrir o menu dispararia um `GET /caixa/<loja>` a cada
/// toque no hambúrguer, para um dado que não muda dentro da sessão — e as duas
/// telas poderiam discordar entre si por um instante.
///
/// Guarda só o `bool`, não o caixa: quem precisa do caixa em si é o painel, que
/// o busca para desenhar o card e **semeia** este cache com o resultado. Na
/// prática a requisição extra acontece só se o menu for aberto antes de o painel
/// ter respondido.
///
/// Singleton simples, no estilo do [ContasCache] e do [CartoesCache]: ninguém
/// precisa reconstruir a árvore quando o valor chega — quem usa pergunta no
/// momento em que vai desenhar.
class CaixaCache {
  static final CaixaCache _instance = CaixaCache._internal();

  factory CaixaCache() => _instance;

  CaixaCache._internal();

  final ApiService _api = ApiService();

  /// `null` é "ainda não sei", e é diferente de `false`. Quem desenha trata os
  /// dois igual (esconde), mas só o `false` é resposta: mostrar o item e
  /// escondê-lo meio segundo depois tiraria a opção de baixo do dedo de quem já
  /// estava tocando nela.
  bool? _temCaixa;

  Future<bool>? _emVoo;

  /// Se a loja tem algum caixa registrado.
  ///
  /// Falha de rede **não** é guardada: devolve `false` e deixa o cache vazio,
  /// para a tentativa seguinte tentar de novo. O efeito de falhar é o atalho de
  /// Caixas não aparecer nesta abertura do menu — e não um menu travado.
  /// Falha de rede **não** escapa para quem chamou: o pedido que vai para o
  /// [_emVoo] é o **já tratado**, e não o cru.
  ///
  /// A diferença não é estilo. Guardando o pedido cru, o `try` protegia apenas
  /// o primeiro chamador: o segundo entrava pelo "já tem um em voo", recebia a
  /// promessa que falha e a exceção estourava do lado dele, sem tratamento. Era
  /// o que acontecia quando a tela e o modal pediam a lista ao mesmo tempo.
  Future<bool> obter({bool recarregar = false}) {
    if (!recarregar && _temCaixa != null) return Future.value(_temCaixa!);

    final emVoo = _emVoo;
    if (emVoo != null) return emVoo;

    final pedido = _buscar();
    _emVoo = pedido;
    return pedido;
  }

  Future<bool> _buscar() async {
    try {
      final tem = await _api.getCaixa().then((caixa) => caixa != null);
      _temCaixa = tem;
      return tem;
    } catch (_) {
      // O ApiService já registrou o erro no log remoto com endpoint e corpo.
      return false;
    } finally {
      _emVoo = null;
    }
  }

  /// O que já se sabe, sem ir à rede. `null` é "ainda não sei".
  bool? get temCaixa => _temCaixa;

  /// Preenche com o que o painel já buscou, sem uma segunda requisição.
  void semear({required bool temCaixa}) => _temCaixa = temCaixa;

  /// Esvazia no logout: a resposta é de uma loja, e a sessão seguinte pode ser
  /// de outra.
  void limpar() {
    _temCaixa = null;
    _emVoo = null;
  }
}
