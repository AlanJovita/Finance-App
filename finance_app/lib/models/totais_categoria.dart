/// Quanto cada categoria e cada subcategoria movimentou no mês
/// (`GET /categoria/totais/<id>?mes=YYYY-MM`).
///
/// Escrito à mão, como `conta.dart` e `resumo_fluxo.dart`: são duas classes
/// rasas e o json_serializable aqui só acrescentaria um `.g.dart` para gerar o
/// que cabe em três linhas.
library;

double _double(dynamic v) =>
    v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

int _int(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

List<Map<String, dynamic>> _lista(dynamic v) =>
    (v as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

/// O total de um grupo no mês — uma linha da tabela de Categorias.
///
/// Serve para categoria e para subcategoria: as duas tabelas da tela têm as
/// mesmas colunas, e o que muda é só de qual lista a linha vem.
///
/// **O valor inclui as compras do cartão de crédito**, pela categoria de cada
/// compra e atribuídas ao vencimento da fatura. É de propósito: é o mesmo número
/// do gráfico "Despesas por categoria" do Resumo, e a mesma categoria no mesmo
/// mês não pode mostrar um valor numa tela e outro na outra. A consequência
/// aceita é que a lista de lançamentos que a tela abre ao clicar soma **menos**
/// que isto quando há cartão na categoria — ela só tem `finance_fluxo_caixa`.
class TotalGrupo {
  /// `id_categoria` ou `id_subcategoria`, conforme a lista de origem. 0 é o
  /// grupo "sem categoria"/"sem subcategoria", que a tela não lista (ela
  /// percorre o cadastro) mas que existe na resposta — é contra a soma dos
  /// grupos que se confere o total do mês.
  final int id;

  /// 1 receita, 2 despesa. É por ele que a aba em foco filtra a lista.
  final int tipoFluxo;

  final double valor;

  /// Quantos movimentos entraram no grupo, cartão incluído.
  final int quantidade;

  const TotalGrupo({
    required this.id,
    required this.tipoFluxo,
    required this.valor,
    required this.quantidade,
  });

  factory TotalGrupo.fromJson(Map<String, dynamic> json) => TotalGrupo(
    // A chave muda com a lista; ler as duas deixa a classe servir às duas
    // tabelas sem um segundo `fromJson` idêntico.
    id: _int(json['id_categoria'] ?? json['id_subcategoria']),
    tipoFluxo: _int(json['tipo_fluxo']),
    valor: _double(json['valor']),
    quantidade: _int(json['quantidade']),
  );
}

/// A resposta inteira: os dois agrupamentos do mês, numa requisição.
///
/// Uma e não duas porque a tela desenha as duas tabelas lado a lado e não serve
/// para nada ter meia tela — a mesma razão do `/fluxo/resumo/painel`.
class TotaisCategorias {
  /// `YYYY-MM` como o **servidor** o resolveu. A tela não recalcula o mês
  /// corrente: o relógio do aparelho pode estar noutro dia.
  final String mes;

  /// Maior primeiro, dentro de cada natureza.
  final List<TotalGrupo> categorias;
  final List<TotalGrupo> subcategorias;

  const TotaisCategorias({
    required this.mes,
    required this.categorias,
    required this.subcategorias,
  });

  const TotaisCategorias.vazio()
      : mes = '',
        categorias = const [],
        subcategorias = const [];

  factory TotaisCategorias.fromJson(Map<String, dynamic> json) =>
      TotaisCategorias(
        mes: '${json['mes'] ?? ''}',
        categorias: _lista(json['categorias']).map(TotalGrupo.fromJson).toList(),
        subcategorias:
            _lista(json['subcategorias']).map(TotalGrupo.fromJson).toList(),
      );

  /// Mapa por id, que é como a tabela resolve o total de cada linha do cadastro.
  ///
  /// Um mapa e não uma busca por linha: a tela percorre o cadastro de categorias
  /// (que é quem tem nome, cor e ícone) e procura o total de cada uma aqui — uma
  /// varredura por linha a cada rebuild seria O(n²) numa lista que o lojista
  /// rola.
  Map<int, TotalGrupo> porCategoria(int tipoFluxo) => {
    for (final g in categorias)
      if (g.tipoFluxo == tipoFluxo) g.id: g,
  };

  /// Subcategoria não precisa do recorte de natureza: ela pertence a **uma**
  /// categoria, que já tem a sua. O id é único na tabela.
  Map<int, TotalGrupo> get porSubcategoria => {
    for (final g in subcategorias) g.id: g,
  };
}
