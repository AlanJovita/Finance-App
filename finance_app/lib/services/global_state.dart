class GlobalState {
  static final GlobalState _instance = GlobalState._internal();

  factory GlobalState() {
    return _instance;
  }

  GlobalState._internal();

  List<int> idLojas = [];
  int? idCliente;

  /// CNPJ do usuário logado, só dígitos.
  ///
  /// Serve à consulta de boletos no api-master, cuja rota é
  /// `/v1/pagamento/link/<cnpj_cpf>/<id_cliente>`. Na prática o CNPJ só é usado
  /// lá quando o cliente ainda não está em `cliente_pagamento` — para os que
  /// já estão, o id basta. Mandá-lo mesmo assim cobre o cliente recém-criado.
  ///
  /// Quem mantém isto em dia é o `AuthProvider`, junto com [idLojas].
  String cnpj = '';

  int get firstIdLoja => idLojas.isNotEmpty ? idLojas.first : 0;
}
