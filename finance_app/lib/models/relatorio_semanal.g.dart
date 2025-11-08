// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relatorio_semanal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RelatorioSemanal _$RelatorioSemanalFromJson(Map<String, dynamic> json) =>
    RelatorioSemanal(
      idLoja: (json['id_loja'] as num?)?.toInt(),
      diaSemana: (json['dia_semana'] as num?)?.toInt(),
      mediaSaldo: (json['media_saldo'] as num?)?.toDouble(),
      mediaPedidosConfirmados:
          (json['media_pedidos_confirmados'] as num?)?.toDouble(),
      recordSaldo: (json['record_saldo'] as num?)?.toDouble(),
      recordPedidosConfirmados:
          (json['record_pedidos_confirmados'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RelatorioSemanalToJson(RelatorioSemanal instance) =>
    <String, dynamic>{
      'id_loja': instance.idLoja,
      'dia_semana': instance.diaSemana,
      'media_saldo': instance.mediaSaldo,
      'media_pedidos_confirmados': instance.mediaPedidosConfirmados,
      'record_saldo': instance.recordSaldo,
      'record_pedidos_confirmados': instance.recordPedidosConfirmados,
    };
