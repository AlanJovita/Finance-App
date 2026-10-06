import 'fluxo_caixa.dart';

double _double(dynamic v) =>
    v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

int _int(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// Total de um mês, vindo somado do banco (`GET /fluxo/resumo/mensal/<id>`).
///
/// Existe para a tela montar os cabeçalhos de mês sem baixar lançamento nenhum:
/// antes ela puxava o histórico inteiro e somava em Dart, o que crescia sem
/// limite junto com o número de lançamentos da loja.
class ResumoMes {
  /// Nulos quando o lançamento não tem vencimento — o grupo "Sem data".
  final int? ano;
  final int? mes;
  final double total;
  final double totalRealizado;
  final int quantidade;

  const ResumoMes({
    required this.ano,
    required this.mes,
    required this.total,
    required this.totalRealizado,
    required this.quantidade,
  });

  factory ResumoMes.fromJson(Map<String, dynamic> json) => ResumoMes(
    ano: json['ano'] == null ? null : _int(json['ano']),
    mes: json['mes'] == null ? null : _int(json['mes']),
    total: _double(json['total']),
    totalRealizado: _double(json['total_realizado']),
    quantidade: _int(json['quantidade']),
  );

  /// Mesma chave usada pela tela para agrupar e controlar a expansão.
  String get chave => (ano == null || mes == null) ? 'sem-data' : '$ano-$mes';

  bool get semData => ano == null || mes == null;
}

/// Uma página de lançamentos (`GET /fluxo/list/<id>?pagina=&por_pagina=`).
class PaginaFluxos {
  final List<FluxoCaixa> itens;
  final int pagina;
  final int porPagina;
  final int total;
  final bool temProxima;

  const PaginaFluxos({
    required this.itens,
    required this.pagina,
    required this.porPagina,
    required this.total,
    required this.temProxima,
  });

  factory PaginaFluxos.fromJson(Map<String, dynamic> json) => PaginaFluxos(
    itens:
        (json['itens'] as List<dynamic>? ?? [])
            .map((e) => FluxoCaixa.fromJson(e as Map<String, dynamic>))
            .toList(),
    pagina: _int(json['pagina']),
    porPagina: _int(json['por_pagina']),
    total: _int(json['total']),
    temProxima: json['tem_proxima'] == true,
  );
}

/// Totais do período (`GET /fluxo/resumo/<id>`).
///
/// `previsto` é tudo que não foi cancelado; `realizado` é só o que está
/// confirmado — a conta lançada contra a conta efetivamente paga/recebida.
class ResumoFluxo {
  final double receitasPrevisto;
  final double despesasPrevisto;
  final double saldoPrevisto;
  final double receitasRealizado;
  final double despesasRealizado;
  final double saldoRealizado;
  final int quantidade;

  const ResumoFluxo({
    required this.receitasPrevisto,
    required this.despesasPrevisto,
    required this.saldoPrevisto,
    required this.receitasRealizado,
    required this.despesasRealizado,
    required this.saldoRealizado,
    required this.quantidade,
  });

  factory ResumoFluxo.fromJson(Map<String, dynamic> json) => ResumoFluxo(
    receitasPrevisto: _double(json['receitas_previsto']),
    despesasPrevisto: _double(json['despesas_previsto']),
    saldoPrevisto: _double(json['saldo_previsto']),
    receitasRealizado: _double(json['receitas_realizado']),
    despesasRealizado: _double(json['despesas_realizado']),
    saldoRealizado: _double(json['saldo_realizado']),
    quantidade: _int(json['quantidade']),
  );
}
