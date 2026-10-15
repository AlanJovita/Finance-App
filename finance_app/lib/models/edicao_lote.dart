/// Os campos que a edição em lote sabe alterar.
///
/// **Nem todos existem nas duas telas.** `MovimentoCartao` não tem `id_conta`
/// nem `confirmado`: compra no cartão não sai do caixa e quem se paga é a
/// fatura. Por isso a tela diz quais campos oferece, em vez de o modal assumir
/// os quatro — ver [CampoLote.doCartao].
enum CampoLote {
  conta('id_conta', 'Conta'),
  categoria('id_categoria', 'Categoria'),
  subcategoria('id_subcategoria', 'Subcategoria'),
  confirmado('confirmado', 'Confirmado');

  const CampoLote(this.coluna, this.rotulo);

  /// Nome da coluna como a API o espera.
  final String coluna;

  /// Como o campo é chamado na tela e na mensagem de confirmação.
  final String rotulo;

  /// O que as telas de Receitas e Despesas oferecem.
  static const List<CampoLote> doFluxo = CampoLote.values;

  /// O que a tela de lançamentos do cartão oferece.
  static const List<CampoLote> doCartao = [
    CampoLote.categoria,
    CampoLote.subcategoria,
  ];
}

/// O que o modal em lote devolve: só os campos que foram preenchidos.
///
/// **Chave ausente é "não mexer"**, e é isso que faz o lote gravar apenas o que
/// o lojista tocou. O mapa vai direto para o corpo da requisição, e a API
/// escreve só as colunas que recebe — ver `FinanceBLL.UpdateFluxoCaixaLote`.
///
/// Repare que 0 é um valor legítimo, não ausência: é "sem conta" e "sem
/// subcategoria" no app inteiro, e tem de ser escrito.
class AlteracaoLote {
  const AlteracaoLote(this.valores);

  final Map<CampoLote, Object> valores;

  bool get vazia => valores.isEmpty;

  /// Os rótulos do que será alterado, na ordem em que aparecem no modal — é o
  /// que a mensagem de confirmação lista.
  List<String> get rotulos => [
    for (final campo in CampoLote.values)
      if (valores.containsKey(campo)) campo.rotulo,
  ];

  Map<String, Object> get corpo => {
    for (final entrada in valores.entries) entrada.key.coluna: entrada.value,
  };
}

/// O que a API respondeu ao lote.
class ResultadoLote {
  const ResultadoLote({required this.atualizados, required this.selecionados});

  /// Linhas que o banco de fato mudou. Pode ser menos que o selecionado quando
  /// alguma já estava com o valor pedido.
  final int atualizados;

  /// Quantas linhas a requisição pediu. No cartão isso difere de [atualizados]
  /// também quando parte da seleção estava em fatura fechada, que a API recusa
  /// em silêncio.
  final int selecionados;

  /// Alguma linha ficou de fora por regra da API, e não por já estar igual.
  bool get houveRecusa => atualizados < selecionados;
}
