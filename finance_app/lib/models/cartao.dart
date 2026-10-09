/// Cartão de crédito e os derivados que as duas telas dele consomem.
///
/// Escrito à mão, como `conta.dart` e `resumo_fluxo.dart`: são classes rasas e o
/// json_serializable aqui só acrescentaria `.g.dart` para gerar o que cabe em
/// poucas linhas.
///
/// ## A ideia que organiza o arquivo
///
/// Compra no cartão **não é saída de caixa**. O dinheiro sai quando a fatura é
/// paga, e o que entra em `finance_fluxo_caixa` é só a despesa da fatura, gerada
/// no fechamento. Daí o invariante que a API mantém e que explica quase tudo
/// aqui: **no máximo uma despesa no caixa por fatura**, apontada por
/// [Fatura.idFluxo]. Pagar a fatura dá baixa nessa despesa; não cria outra.
library;

double _double(dynamic v) =>
    v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

int _int(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// A API devolve as datas do cartão em ISO (`YYYY-MM-DD`), e não no `d/M/yyyy`
/// do `FluxoCaixa`: estas datas são comparadas e ordenadas aqui (vencimento ×
/// hoje, navegador de meses).
DateTime? _data(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

/// Situação de uma fatura. Os códigos são os da coluna `status`.
enum StatusFatura {
  /// Aceita lançamento. Ainda não gerou despesa no caixa.
  aberta(1, 'Aberta'),

  /// Valor congelado e despesa gerada no caixa, à espera do pagamento.
  fechada(2, 'Fechada'),

  /// Quitada: a despesa dela no caixa está confirmada.
  paga(3, 'Paga');

  const StatusFatura(this.codigo, this.rotulo);

  final int codigo;
  final String rotulo;

  static StatusFatura de(int codigo) => switch (codigo) {
    2 => StatusFatura.fechada,
    3 => StatusFatura.paga,
    // Código desconhecido cai em aberta, que é o estado que não promete nada:
    // tratá-lo como fechada faria a tela oferecer um pagamento sem despesa
    // nenhuma em que dar baixa.
    _ => StatusFatura.aberta,
  };
}

/// Natureza de um movimento. `tipoFluxo` já diz o sinal; a natureza diz **o que**
/// o crédito é — e a distinção importa porque só uma delas move o caixa.
enum NaturezaMovimento {
  compra(0, 'Compra'),

  /// Pagamento da fatura: abate o cartão **e** corresponde a uma saída de caixa.
  /// É o único crédito que move dinheiro, e por isso é registrado pela fatura
  /// (`pagarFatura`), não pelo lançamento comum.
  pagamento(1, 'Pagamento de fatura'),

  /// Devolução de compra: o crédito volta para o cartão, e nada sai do caixa.
  estorno(2, 'Estorno / devolução'),

  /// Cashback, bônus, crédito do emissor: também não move o caixa.
  cashback(3, 'Cashback / crédito');

  const NaturezaMovimento(this.codigo, this.rotulo);

  final int codigo;
  final String rotulo;

  static NaturezaMovimento de(int codigo) => switch (codigo) {
    1 => NaturezaMovimento.pagamento,
    2 => NaturezaMovimento.estorno,
    3 => NaturezaMovimento.cashback,
    _ => NaturezaMovimento.compra,
  };

  /// As que o modal de lançamento oferece para uma receita no cartão. Pagamento
  /// fica fora: ele é registrado pela fatura, porque paga uma fatura *escolhida*
  /// e dá baixa na despesa dela.
  static const List<NaturezaMovimento> creditosLancaveis = [
    NaturezaMovimento.estorno,
    NaturezaMovimento.cashback,
  ];
}

/// Cadastro de um cartão (`finance_cartao`).
///
/// `diaFechamento` e `diaVencimento` são **dias do mês**, não datas: o cartão
/// repete o ciclo todo mês, e o par de datas de cada ciclo fica congelado na
/// [Fatura] daquele mês. Mudar o ciclo aqui não redata as faturas que já
/// existem — elas fecharam no dia em que fecharam.
class Cartao {
  final int id;
  final int idCliente;
  final String descricao;

  /// Falso é cartão arquivado: sai do seletor de lançamento, mas continua na
  /// página de Cartões com saldo devedor e histórico. É o "status" do cadastro.
  final bool ativado;

  /// Chave do catálogo de bandeiras (`utils/bandeiras.dart`).
  final String bandeira;

  /// Chave do catálogo de **bancos** (`utils/bancos.dart`), que é o código
  /// COMPE — o mesmo catálogo da conta bancária, porque o emissor de um cartão é
  /// um banco.
  final String banco;

  /// 0 é "sem limite informado", e aí a tela não mostra limite disponível em vez
  /// de mostrar um disponível negativo inventado.
  final double limite;

  /// Conta bancária que paga a fatura; 0 é "sem conta". Entra como `id_conta` da
  /// despesa gerada no fechamento, para a fatura debitar a conta certa no saldo
  /// da página de Contas.
  final int idConta;

  final int diaFechamento;
  final int diaVencimento;

  /// Categoria que a despesa da fatura recebe no caixa; 0 é "sem categoria".
  /// Fica no cartão e não é escolhida a cada fechamento porque a resposta é
  /// sempre a mesma.
  final int idCategoria;

  const Cartao({
    required this.id,
    required this.idCliente,
    required this.descricao,
    this.ativado = true,
    this.bandeira = '',
    this.banco = '',
    this.limite = 0.0,
    this.idConta = 0,
    this.diaFechamento = 1,
    this.diaVencimento = 10,
    this.idCategoria = 0,
  });

  factory Cartao.fromJson(Map<String, dynamic> json) => Cartao(
    id: _int(json['id']),
    idCliente: _int(json['id_cliente'] ?? json['id_loja']),
    descricao: (json['descricao'] ?? '').toString(),
    ativado: json['ativado'] != false,
    bandeira: (json['bandeira'] ?? '').toString(),
    banco: (json['banco'] ?? '').toString(),
    limite: _double(json['limite']),
    idConta: _int(json['id_conta']),
    diaFechamento: _int(json['dia_fechamento']),
    diaVencimento: _int(json['dia_vencimento']),
    idCategoria: _int(json['id_categoria']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'id_cliente': idCliente,
    'descricao': descricao,
    'ativado': ativado,
    'bandeira': bandeira,
    'banco': banco,
    'limite': limite,
    'id_conta': idConta,
    'dia_fechamento': diaFechamento,
    'dia_vencimento': diaVencimento,
    'id_categoria': idCategoria,
  };

  Cartao copyWith({
    int? id,
    int? idCliente,
    String? descricao,
    bool? ativado,
    String? bandeira,
    String? banco,
    double? limite,
    int? idConta,
    int? diaFechamento,
    int? diaVencimento,
    int? idCategoria,
  }) => Cartao(
    id: id ?? this.id,
    idCliente: idCliente ?? this.idCliente,
    descricao: descricao ?? this.descricao,
    ativado: ativado ?? this.ativado,
    bandeira: bandeira ?? this.bandeira,
    banco: banco ?? this.banco,
    limite: limite ?? this.limite,
    idConta: idConta ?? this.idConta,
    diaFechamento: diaFechamento ?? this.diaFechamento,
    diaVencimento: diaVencimento ?? this.diaVencimento,
    idCategoria: idCategoria ?? this.idCategoria,
  );
}

/// Um cartão com o saldo devedor e o recorte por fatura
/// (`GET /cartao/resumo/<id>`).
///
/// Sem parâmetro de período, ao contrário de `SaldoConta`: dívida de cartão é um
/// número de **agora**, não um acumulado até uma data. Quem navega por mês é a
/// tela da fatura.
class ResumoCartao {
  final int id;
  final String descricao;
  final bool ativado;
  final String bandeira;
  final String banco;
  final double limite;
  final int idConta;
  final int diaFechamento;
  final int diaVencimento;

  /// Vai no resumo só para o formulário de edição reabrir direto do cartão que
  /// está na tela, sem uma segunda consulta — é o único campo do cadastro que o
  /// resumo não precisaria.
  final int idCategoria;

  /// Tudo que não foi pago, **inclusive as parcelas de faturas futuras**. É o
  /// número que faz `limite − devedor` bater com o limite disponível que o banco
  /// mostra.
  final double saldoDevedor;

  /// Os quatro baldes do [saldoDevedor]. São disjuntos e somam exatamente ele.
  final double faturaAtual;
  final double emAtraso;
  final double aVencer;
  final double parcelasFuturas;

  /// `null` quando o lojista não informou o limite: um "disponível" sem limite
  /// seria invenção.
  final double? limiteDisponivel;

  /// A competência que uma compra de hoje receberia — a fatura aberta.
  final DateTime? competenciaAtual;
  final DateTime? fechamentoAtual;
  final DateTime? vencimentoAtual;

  /// Quantos lançamentos o cartão tem — alimenta o aviso do delete.
  final int quantidade;

  const ResumoCartao({
    required this.id,
    required this.descricao,
    required this.ativado,
    required this.bandeira,
    required this.banco,
    required this.limite,
    required this.idConta,
    required this.diaFechamento,
    required this.diaVencimento,
    required this.idCategoria,
    required this.saldoDevedor,
    required this.faturaAtual,
    required this.emAtraso,
    required this.aVencer,
    required this.parcelasFuturas,
    required this.limiteDisponivel,
    required this.competenciaAtual,
    required this.fechamentoAtual,
    required this.vencimentoAtual,
    required this.quantidade,
  });

  factory ResumoCartao.fromJson(Map<String, dynamic> json) => ResumoCartao(
    id: _int(json['id']),
    descricao: (json['descricao'] ?? '').toString(),
    ativado: json['ativado'] != false,
    bandeira: (json['bandeira'] ?? '').toString(),
    banco: (json['banco'] ?? '').toString(),
    limite: _double(json['limite']),
    idConta: _int(json['id_conta']),
    diaFechamento: _int(json['dia_fechamento']),
    diaVencimento: _int(json['dia_vencimento']),
    idCategoria: _int(json['id_categoria']),
    saldoDevedor: _double(json['saldo_devedor']),
    faturaAtual: _double(json['fatura_atual']),
    emAtraso: _double(json['em_atraso']),
    aVencer: _double(json['a_vencer']),
    parcelasFuturas: _double(json['parcelas_futuras']),
    // `null` é diferente de 0 aqui, então não passa pelo `_double`.
    limiteDisponivel:
        json['limite_disponivel'] == null
            ? null
            : _double(json['limite_disponivel']),
    competenciaAtual: _data(json['competencia_atual']),
    fechamentoAtual: _data(json['fechamento_atual']),
    vencimentoAtual: _data(json['vencimento_atual']),
    quantidade: _int(json['quantidade']),
  );

  /// Nada lançado e nada devido — o cartão recém-cadastrado.
  bool get vazio => quantidade == 0;

  /// Quanto do limite está comprometido, de 0 a 1. `null` sem limite informado.
  double? get usoDoLimite {
    if (limite <= 0) return null;
    return (saldoDevedor / limite).clamp(0.0, 1.0);
  }

  /// O cadastro, para reabrir o formulário sem uma consulta a mais: a resposta
  /// do resumo já traz todos os campos de um [Cartao].
  Cartao paraCartao(int idCliente) => Cartao(
    id: id,
    idCliente: idCliente,
    descricao: descricao,
    ativado: ativado,
    bandeira: bandeira,
    banco: banco,
    limite: limite,
    idConta: idConta,
    diaFechamento: diaFechamento,
    diaVencimento: diaVencimento,
    idCategoria: idCategoria,
  );
}

/// Uma fatura (`finance_cartao_fatura`).
///
/// `id == 0` é a **fatura vazia**: a competência ainda não tem lançamento
/// nenhum, então não existe linha no banco e a API devolve as datas calculadas do
/// ciclo do cartão. Não é erro nem ausência — é o mês em branco, e o primeiro
/// lançamento cria a linha.
class Fatura {
  final int id;
  final int idCartao;

  /// O mês da fatura, sempre no dia 1. É a identidade dela.
  final DateTime? competencia;

  final DateTime? dataFechamento;

  /// **Pode cair no mês seguinte** ao fechamento (fecha 28/10, vence 05/11): é o
  /// primeiro dia de vencimento depois do fechamento.
  final DateTime? dataVencimento;

  final StatusFatura status;

  /// Valor congelado no fechamento. 0 enquanto aberta — aí quem vale é
  /// [TotaisFatura.valor], a soma ao vivo.
  final double valorTotal;

  /// A despesa que o fechamento gerou no caixa; 0 enquanto aberta.
  final int idFluxo;

  const Fatura({
    required this.id,
    required this.idCartao,
    required this.competencia,
    required this.dataFechamento,
    required this.dataVencimento,
    required this.status,
    required this.valorTotal,
    required this.idFluxo,
  });

  factory Fatura.fromJson(Map<String, dynamic> json) => Fatura(
    id: _int(json['id']),
    idCartao: _int(json['id_cartao']),
    competencia: _data(json['competencia']),
    dataFechamento: _data(json['data_fechamento']),
    dataVencimento: _data(json['data_vencimento']),
    status: StatusFatura.de(_int(json['status'])),
    valorTotal: _double(json['valor_total']),
    idFluxo: _int(json['id_fluxo']),
  );

  bool get aberta => status == StatusFatura.aberta;
  bool get paga => status == StatusFatura.paga;

  /// A competência na forma curta que a API aceita na URL (`YYYY-MM`).
  String get chave => competencia == null ? '' : chaveCompetencia(competencia!);

  /// Já passou do dia do fechamento e a fatura continua aberta: é quando a tela
  /// oferece "Fechar fatura".
  ///
  /// Fechar antes do dia é legítimo (lojista que confere adiantado) e a API não
  /// trava a data — mas oferecer o botão antes faria o fechamento parecer parte
  /// do lançamento, e o lojista fecharia um mês que ainda vai receber compras.
  bool get podeFechar {
    if (!aberta) return false;
    final fechamento = dataFechamento;
    if (fechamento == null) return false;
    final hoje = DateTime.now();
    return !DateTime(fechamento.year, fechamento.month, fechamento.day).isAfter(
      DateTime(hoje.year, hoje.month, hoje.day),
    );
  }

  /// Fechada, com saldo e vencimento já passado.
  bool get vencida {
    if (status != StatusFatura.fechada) return false;
    final vencimento = dataVencimento;
    if (vencimento == null) return false;
    final hoje = DateTime.now();
    return DateTime(vencimento.year, vencimento.month, vencimento.day).isBefore(
      DateTime(hoje.year, hoje.month, hoje.day),
    );
  }
}

/// `YYYY-MM` — a forma curta da competência, que é o que a API aceita na URL.
///
/// O mês é a identidade da fatura, e um dia na query string só convidaria a
/// mandar dias diferentes para a mesma fatura.
String chaveCompetencia(DateTime mes) =>
    '${mes.year.toString().padLeft(4, '0')}-'
    '${mes.month.toString().padLeft(2, '0')}';

/// Os totais de uma fatura, já somados no banco.
class TotaisFatura {
  final double compras;

  /// Estorno e cashback — os créditos que **reduzem a fatura**.
  final double creditos;

  /// O valor da fatura: `compras − creditos`. Depois do fechamento é o congelado
  /// em [Fatura.valorTotal].
  final double valor;

  /// Pagamentos registrados nesta fatura. **Não** entra em [valor]: pagamento
  /// abate o saldo, não o valor da fatura — somá-lo junto a zeraria ao pagá-la e
  /// ninguém saberia mais de quanto ela era.
  final double pago;

  /// `valor − pago`. É o que falta pagar.
  final double saldo;

  final int quantidade;

  const TotaisFatura({
    required this.compras,
    required this.creditos,
    required this.valor,
    required this.pago,
    required this.saldo,
    required this.quantidade,
  });

  factory TotaisFatura.fromJson(Map<String, dynamic> json) => TotaisFatura(
    compras: _double(json['compras']),
    creditos: _double(json['creditos']),
    valor: _double(json['valor']),
    pago: _double(json['pago']),
    saldo: _double(json['saldo']),
    quantidade: _int(json['quantidade']),
  );

  static const TotaisFatura vazio = TotaisFatura(
    compras: 0,
    creditos: 0,
    valor: 0,
    pago: 0,
    saldo: 0,
    quantidade: 0,
  );

  /// Pago em parte, mas não quitado. A API registra o crédito no cartão e
  /// **não** baixa a despesa no caixa nesse caso — baixá-la pela parte paga
  /// exigiria modelar crédito rotativo.
  bool get pagoParcialmente => pago > 0.005 && saldo > 0.005;
}

/// Um lançamento no cartão (`finance_cartao_movimento`).
///
/// Não tem `confirmado`: no cartão não existe baixa de lançamento. O que liquida
/// uma compra é o pagamento da fatura em que ela caiu.
class MovimentoCartao {
  final int id;
  final int idCliente;
  final int idCartao;

  /// A fatura em que caiu. Resolvida pela API no INSERT, a partir de
  /// [dataLancamento] e do ciclo do cartão — nunca na leitura.
  final int idFatura;

  final int idCategoria;
  final int idSubcategoria;
  final String descricao;
  final double valor;

  /// 1 receita (crédito), 2 despesa (compra) — o mesmo código do caixa.
  final int tipoFluxo;

  final NaturezaMovimento natureza;
  final bool cancelado;
  final DateTime? dataCriacao;

  /// A data da **compra**. É ela que decidiu em qual fatura o lançamento caiu, e
  /// é igual nas N parcelas de um parcelamento — a compra aconteceu uma vez.
  final DateTime? dataLancamento;

  final int repeticao;

  /// "[3/12]" sai daqui, não de um parse da descrição.
  final int parcela;
  final int totalParcelas;

  /// Agrupador do lote de parcelas. **É o seletor** do delete: positivo apaga a
  /// compra inteira, 0 apaga a linha.
  final int idRef;

  const MovimentoCartao({
    required this.id,
    required this.idCliente,
    required this.idCartao,
    required this.idFatura,
    required this.idCategoria,
    required this.idSubcategoria,
    required this.descricao,
    required this.valor,
    required this.tipoFluxo,
    required this.natureza,
    required this.cancelado,
    required this.dataCriacao,
    required this.dataLancamento,
    required this.repeticao,
    required this.parcela,
    required this.totalParcelas,
    required this.idRef,
  });

  factory MovimentoCartao.fromJson(Map<String, dynamic> json) =>
      MovimentoCartao(
        id: _int(json['id']),
        idCliente: _int(json['id_cliente'] ?? json['id_loja']),
        idCartao: _int(json['id_cartao']),
        idFatura: _int(json['id_fatura']),
        idCategoria: _int(json['id_categoria']),
        idSubcategoria: _int(json['id_subcategoria']),
        descricao: (json['descricao'] ?? '').toString(),
        valor: _double(json['valor']),
        tipoFluxo: _int(json['tipo_fluxo']),
        natureza: NaturezaMovimento.de(_int(json['natureza'])),
        cancelado: json['cancelado'] == true,
        dataCriacao: _data(json['data_criacao']),
        dataLancamento: _data(json['data_lancamento']),
        repeticao: _int(json['repeticao']),
        parcela: _int(json['parcela']),
        totalParcelas: _int(json['total_parcelas']),
        idRef: _int(json['id_ref']),
      );

  /// O que o POST manda. `id_fatura` fica fora de propósito: quem resolve a
  /// fatura é a API, a partir da data e do ciclo do cartão — mandá-la daqui seria
  /// o app decidindo a regra central do cartão com uma cópia da conta.
  Map<String, dynamic> toJson() => {
    'id': id,
    'id_cliente': idCliente,
    'id_cartao': idCartao,
    'id_categoria': idCategoria,
    'id_subcategoria': idSubcategoria,
    'descricao': descricao,
    'valor': valor,
    'tipo_fluxo': tipoFluxo,
    'natureza': natureza.codigo,
    'cancelado': cancelado,
    'data_criacao': dataCriacao?.toIso8601String(),
    'data_lancamento': dataLancamento?.toIso8601String(),
    'repeticao': repeticao,
    'total_parcelas': totalParcelas,
  };

  bool get ehCredito => tipoFluxo == 1;
  bool get ehPagamento => natureza == NaturezaMovimento.pagamento;
  bool get ehParcelado => totalParcelas > 1;

  /// "3/12", ou vazio quando não é parcelado.
  String get rotuloParcela => ehParcelado ? '$parcela/$totalParcelas' : '';
}

/// Uma fatura com os totais e os movimentos — a resposta de
/// `GET /cartao/fatura/<cliente>/<cartao>`.
///
/// Uma requisição e não três: a tela precisa das três coisas juntas em toda troca
/// de mês, e separá-las só multiplicaria a latência do navegador de faturas.
class FaturaDetalhe {
  final Fatura fatura;
  final TotaisFatura totais;
  final List<MovimentoCartao> movimentos;

  const FaturaDetalhe({
    required this.fatura,
    required this.totais,
    required this.movimentos,
  });

  factory FaturaDetalhe.fromJson(Map<String, dynamic> json) => FaturaDetalhe(
    fatura: Fatura.fromJson(
      (json['fatura'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    totais: TotaisFatura.fromJson(
      (json['totais'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    movimentos: [
      for (final m in (json['movimentos'] as List? ?? const []))
        MovimentoCartao.fromJson((m as Map).cast<String, dynamic>()),
    ],
  );
}

/// Uma linha do atalho de faturas (`GET /cartao/faturas/<cliente>/<cartao>`).
///
/// Mesmo papel do `ResumoMes` nas telas de Receitas e Despesas: diz em quais
/// meses há algo, sem baixar os movimentos de nenhum deles.
class ResumoFatura {
  final int id;
  final DateTime? competencia;
  final DateTime? dataFechamento;
  final DateTime? dataVencimento;
  final StatusFatura status;
  final double valor;
  final double pago;
  final double saldo;
  final int quantidade;

  const ResumoFatura({
    required this.id,
    required this.competencia,
    required this.dataFechamento,
    required this.dataVencimento,
    required this.status,
    required this.valor,
    required this.pago,
    required this.saldo,
    required this.quantidade,
  });

  factory ResumoFatura.fromJson(Map<String, dynamic> json) => ResumoFatura(
    id: _int(json['id']),
    competencia: _data(json['competencia']),
    dataFechamento: _data(json['data_fechamento']),
    dataVencimento: _data(json['data_vencimento']),
    status: StatusFatura.de(_int(json['status'])),
    valor: _double(json['valor']),
    pago: _double(json['pago']),
    saldo: _double(json['saldo']),
    quantidade: _int(json['quantidade']),
  );

  String get chave => competencia == null ? '' : chaveCompetencia(competencia!);
}
