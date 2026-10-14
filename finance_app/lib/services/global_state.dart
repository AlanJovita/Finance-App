/// Estado da sessão lido por todo o app — quem o mantém em dia é o
/// `AuthProvider`.
///
/// **O `id_cliente` nunca é 0 numa sessão de verdade.** Esta classe é a origem
/// do id que vai em toda requisição e em todo lançamento, e ela já devolveu 0
/// em silêncio: com [idLojas] vazia, o antigo `firstIdLoja` respondia 0, os
/// ~35 chamadores usavam esse 0 sem conferir, e o resultado foi a tela
/// mostrando os dados do "cliente 0" e um lançamento gravado com
/// `id_cliente = 0`. Por isso [idCliente] é derivado, o setter de [idLojas]
/// descarta id inválido e quem precisa do id para escrever pede por
/// [exigirIdCliente] — que recusa em vez de devolver 0.
class GlobalState {
  static final GlobalState _instance = GlobalState._internal();

  factory GlobalState() {
    return _instance;
  }

  GlobalState._internal();

  List<int> _idLojas = [];

  /// Lojas da sessão. Só ids válidos entram: ver o setter.
  List<int> get idLojas => List.unmodifiable(_idLojas);

  /// Descarta 0, negativo e repetido.
  ///
  /// A limpeza fica aqui, e não em quem chama, porque esta é a única porta de
  /// entrada: um `data: [0]` na resposta do login (ou uma chave `id_lojas` do
  /// SharedPreferences corrompida) não pode virar uma sessão que escreve no
  /// cliente 0.
  set idLojas(List<int> valor) {
    final vistos = <int>{};
    _idLojas = [
      for (final id in valor)
        if (id > 0 && vistos.add(id)) id,
    ];
  }

  /// O `id_cliente` da sessão, ou 0 quando não há sessão.
  ///
  /// Derivado de [idLojas]: o app opera uma loja por vez e sempre a primeira —
  /// guardar o id numa segunda variável criaria dois lugares para divergir.
  int get idCliente => _idLojas.isEmpty ? 0 : _idLojas.first;

  /// Nome antigo de [idCliente], mantido pelos chamadores existentes.
  ///
  /// Continua podendo responder 0: é o que o [LoggerService] precisa, porque
  /// um erro ocorrido **sem** sessão ainda tem de ser registrado. Para
  /// qualquer outro uso, prefira [exigirIdCliente].
  int get firstIdLoja => idCliente;

  /// Há sessão utilizável? É a pergunta que libera navegação e escrita.
  bool get sessaoValida => idCliente > 0;

  /// O `id_cliente` da sessão, ou [SessaoInvalidaException].
  ///
  /// Use em todo caminho que leia ou grave dados da loja: falhar alto é o que
  /// impede uma requisição de sair com 0 quando a sessão não terminou de
  /// carregar, ou já terminou.
  int exigirIdCliente([String? origem]) {
    final id = idCliente;
    if (id <= 0) throw SessaoInvalidaException(origem);
    return id;
  }

  /// CNPJ do usuário logado, só dígitos.
  ///
  /// Serve à consulta de boletos no api-master, cuja rota é
  /// `/v1/pagamento/link/<cnpj_cpf>/<id_cliente>`. Na prática o CNPJ só é usado
  /// lá quando o cliente ainda não está em `cliente_pagamento` — para os que
  /// já estão, o id basta. Mandá-lo mesmo assim cobre o cliente recém-criado.
  ///
  /// Quem mantém isto em dia é o `AuthProvider`, junto com [idLojas].
  String cnpj = '';

  /// Esvazia tudo. Chamado pelo `AuthProvider` ao encerrar a sessão.
  void limpar() {
    _idLojas = [];
    cnpj = '';
  }
}

/// Operação pedida sem `id_cliente` na sessão.
///
/// Não é erro de rede nem de validação de formulário: é o app tentando falar
/// da loja de ninguém. A mensagem é a que o usuário pode acabar vendo se algum
/// `catch` de tela a exibir, então ela é escrita para ele.
class SessaoInvalidaException implements Exception {
  /// Onde foi detectado — o nome do método do `ApiService`, normalmente.
  final String? origem;

  const SessaoInvalidaException([this.origem]);

  @override
  String toString() =>
      'Sessão encerrada. Entre novamente para continuar.'
      '${origem == null ? '' : ' ($origem)'}';
}
