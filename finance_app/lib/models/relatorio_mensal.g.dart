// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relatorio_mensal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RelatorioMensal _$RelatorioMensalFromJson(Map<String, dynamic> json) =>
    RelatorioMensal(
      idLoja: (json['id_loja'] as num?)?.toInt(),
      ano: (json['ano'] as num?)?.toInt(),
      mes: (json['mes'] as num?)?.toInt(),
      mediaSaldo: (json['media_saldo'] as num?)?.toDouble(),
      somaSaldo: (json['soma_saldo'] as num?)?.toDouble(),
      somaPedidosConfirmados:
          (json['soma_pedidos_confirmados'] as num?)?.toDouble(),
      mediaPedidosConfirmados:
          (json['media_pedidos_confirmados'] as num?)?.toDouble(),
      somaPedidosEstornados:
          (json['soma_pedidos_estornados'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$RelatorioMensalToJson(RelatorioMensal instance) =>
    <String, dynamic>{
      'id_loja': instance.idLoja,
      'ano': instance.ano,
      'mes': instance.mes,
      'media_saldo': instance.mediaSaldo,
      'soma_saldo': instance.somaSaldo,
      'soma_pedidos_confirmados': instance.somaPedidosConfirmados,
      'media_pedidos_confirmados': instance.mediaPedidosConfirmados,
      'soma_pedidos_estornados': instance.somaPedidosEstornados,
    };
