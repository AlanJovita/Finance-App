/// Conta bancária e os dois derivados que a página de Contas consome.
///
/// Escrito à mão, como `resumo_fluxo.dart`: são três classes rasas, sem data nem
/// enum, e o json_serializable aqui só acrescentaria um `.g.dart` para gerar o que
/// cabe em três linhas.
library;

double _double(dynamic v) =>
    v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

int _int(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// Centro de custo das movimentações (`finance_conta`).
///
/// `id_conta = 0` nos lançamentos é "sem conta" e **não** tem instância desta
/// classe: é o padrão de quem nunca cadastrou conta, e do que chega do PDV. Quem
/// representa esse balde na tela é [SaldoConta] com `id == 0`.
class Conta {
  final int id;
  final int idCliente;
  final String descricao;

  /// Falso é conta arquivada: sai do seletor do modal de lançamento, mas continua
  /// na página de Contas com saldo e histórico.
  final bool ativado;

  /// Chave do catálogo de bancos (`utils/bancos.dart`), que é o código COMPE —
  /// não a imagem. Vazio quando o lojista não escolheu instituição.
  final String imagem;

  /// Saldo da conta antes do primeiro lançamento feito no app. Sem ele o "saldo
  /// atual" seria só a soma do que foi lançado aqui, que quase nunca é o saldo do
  /// extrato.
  final double saldoInicial;

  const Conta({
    required this.id,
    required this.idCliente,
    required this.descricao,
    this.ativado = true,
    this.imagem = '',
    this.saldoInicial = 0.0,
  });

  factory Conta.fromJson(Map<String, dynamic> json) => Conta(
    id: _int(json['id']),
    idCliente: _int(json['id_cliente'] ?? json['id_loja']),
    descricao: (json['descricao'] ?? '').toString(),
    ativado: json['ativado'] != false,
    imagem: (json['imagem'] ?? '').toString(),
    saldoInicial: _double(json['saldo_inicial']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'id_cliente': idCliente,
    'descricao': descricao,
    'ativado': ativado,
    'imagem': imagem,
    'saldo_inicial': saldoInicial,
  };

  Conta copyWith({
    int? id,
    int? idCliente,
    String? descricao,
    bool? ativado,
    String? imagem,
    double? saldoInicial,
  }) => Conta(
    id: id ?? this.id,
    idCliente: idCliente ?? this.idCliente,
    descricao: descricao ?? this.descricao,
    ativado: ativado ?? this.ativado,
    imagem: imagem ?? this.imagem,
    saldoInicial: saldoInicial ?? this.saldoInicial,
  );
}

/// Uma conta com os saldos do mês escolhido (`GET /conta/saldos/<id>?ate=`).
///
/// Os dois saldos são **acumulados** até o fim do mês, não o resultado dele:
/// `saldoAtual` é saldo inicial + o que está confirmado, `saldoPrevisto` soma
/// também o que ainda vai vencer. Saldo de conta que reinicia na virada do mês
/// não é saldo.
///
/// A fatura de cartão **em aberto** já está descontada do `saldoPrevisto`, na
/// conta de pagamento do cartão — ver [faturaAberta].
class SaldoConta {
  final int id;
  final String descricao;
  final bool ativado;
  final String imagem;
  final double saldoInicial;
  final double saldoAtual;
  final double saldoPrevisto;

  /// Quantos lançamentos entraram na conta — alimenta o aviso do delete, que
  /// precisa dizer quantas movimentações serão movidas.
  ///
  /// **Não conta a fatura de cartão em aberto**: ela não é lançamento, e a lista
  /// da conta não tem o que mostrar por ela.
  final int quantidade;

  /// Quanto do [saldoPrevisto] é fatura de cartão ainda **aberta**, já
  /// descontado. Legenda, não dado — a tela não soma nada.
  ///
  /// Existe porque esse valor não tem lançamento nenhum atrás dele: enquanto a
  /// fatura está aberta não há linha em `finance_fluxo_caixa`, e sem o aviso o
  /// lojista procuraria na conta um débito que não está lá. Depois do fechamento
  /// ela vira lançamento comum e sai daqui.
  final double faturaAberta;

  const SaldoConta({
    required this.id,
    required this.descricao,
    required this.ativado,
    required this.imagem,
    required this.saldoInicial,
    required this.saldoAtual,
    required this.saldoPrevisto,
    required this.quantidade,
    this.faturaAberta = 0.0,
  });

  factory SaldoConta.fromJson(Map<String, dynamic> json) => SaldoConta(
    id: _int(json['id']),
    descricao: (json['descricao'] ?? '').toString(),
    ativado: json['ativado'] != false,
    imagem: (json['imagem'] ?? '').toString(),
    saldoInicial: _double(json['saldo_inicial']),
    saldoAtual: _double(json['saldo_atual']),
    saldoPrevisto: _double(json['saldo_previsto']),
    quantidade: _int(json['quantidade']),
    // Ausente é API anterior ao cartão no saldo: o saldo continua certo (a
    // conta é no servidor) e o que falta é só o aviso de origem.
    faturaAberta: _double(json['fatura_aberta']),
  );

  /// A linha do que foi lançado sem conta atribuída. Não é uma conta: não se
  /// edita, não se apaga e não participa de transferência.
  bool get semConta => id == 0;

  /// O que ainda não foi confirmado e já está contado no previsto.
  double get aConfirmar => saldoPrevisto - saldoAtual;

  /// Esta conta paga alguma fatura que ainda está aberta.
  bool get temFaturaAberta => faturaAberta > 0;
}

/// Uma transferência entre contas, já pareada pelo servidor
/// (`GET /conta/transferencias/<id>`).
///
/// No banco são dois lançamentos — despesa na origem, receita no destino — unidos
/// pelo mesmo `id_transferencia`. Aqui é uma linha só, que é como o lojista pensa
/// a operação.
class Transferencia {
  final int idTransferencia;
  final int idContaOrigem;
  final int idContaDestino;
  final double valor;
  final DateTime? data;

  /// Descrição da perna de saída ("Transferência para Nubank"), montada pela API.
  final String descricao;

  const Transferencia({
    required this.idTransferencia,
    required this.idContaOrigem,
    required this.idContaDestino,
    required this.valor,
    required this.data,
    required this.descricao,
  });

  factory Transferencia.fromJson(Map<String, dynamic> json) => Transferencia(
    idTransferencia: _int(json['id_transferencia']),
    idContaOrigem: _int(json['id_conta_origem']),
    idContaDestino: _int(json['id_conta_destino']),
    valor: _double(json['valor']),
    // A API devolve `date` como ISO 8601 (`GenericResult._convert_for_json`).
    data: DateTime.tryParse((json['data'] ?? '').toString()),
    descricao: (json['descricao'] ?? '').toString(),
  );
}
