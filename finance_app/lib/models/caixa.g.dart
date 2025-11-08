// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caixa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Caixa _$CaixaFromJson(Map<String, dynamic> json) => Caixa(
  id: (json['id'] as num?)?.toInt(),
  idLoja: (json['id_loja'] as num).toInt(),
  nomeLoja: json['nome_loja'] as String?,
  idCaixa: (json['id_caixa'] as num?)?.toInt(),
  idUsuario: (json['id_usuario'] as num).toInt(),
  idRefRepeticao: (json['id_ref_repeticao'] as num?)?.toInt(),
  troco: (json['troco'] as num?)?.toDouble(),
  dataAbertura:
      json['data_abertura'] == null
          ? null
          : DateTime.parse(json['data_abertura'] as String),
  dataFechamento:
      json['data_fechamento'] == null
          ? null
          : DateTime.parse(json['data_fechamento'] as String),
  saldo: (json['saldo'] as num?)?.toDouble(),
  statusCaixa: (json['status_caixa'] as num?)?.toInt(),
  saldoDinheiro: (json['saldo_dinheiro'] as num?)?.toDouble(),
  saldoCartao: (json['saldo_cartao'] as num?)?.toDouble(),
  saldoOutras: (json['saldo_outras'] as num?)?.toDouble(),
  saldoPix: (json['saldo_pix'] as num?)?.toDouble(),
  saldoTicket: (json['saldo_ticket'] as num?)?.toDouble(),
  sangria: (json['sangria'] as num?)?.toDouble(),
  suprimento: (json['suprimento'] as num?)?.toDouble(),
  saldoPxCaixa: (json['saldo_px_caixa'] as num?)?.toDouble(),
  saldoNaoFaturado: (json['saldo_nao_faturado'] as num?)?.toDouble(),
  totalPedidoConfirmado: (json['total_pedido_confirmado'] as num?)?.toInt(),
  totalPedidoEstornado: (json['total_pedido_estornado'] as num?)?.toInt(),
);

Map<String, dynamic> _$CaixaToJson(Caixa instance) => <String, dynamic>{
  'id': instance.id,
  'id_loja': instance.idLoja,
  'nome_loja': instance.nomeLoja,
  'id_caixa': instance.idCaixa,
  'id_usuario': instance.idUsuario,
  'id_ref_repeticao': instance.idRefRepeticao,
  'troco': instance.troco,
  'data_abertura': instance.dataAbertura?.toIso8601String(),
  'data_fechamento': instance.dataFechamento?.toIso8601String(),
  'saldo': instance.saldo,
  'status_caixa': instance.statusCaixa,
  'saldo_dinheiro': instance.saldoDinheiro,
  'saldo_cartao': instance.saldoCartao,
  'saldo_outras': instance.saldoOutras,
  'saldo_pix': instance.saldoPix,
  'saldo_ticket': instance.saldoTicket,
  'sangria': instance.sangria,
  'suprimento': instance.suprimento,
  'saldo_px_caixa': instance.saldoPxCaixa,
  'saldo_nao_faturado': instance.saldoNaoFaturado,
  'total_pedido_confirmado': instance.totalPedidoConfirmado,
  'total_pedido_estornado': instance.totalPedidoEstornado,
};
