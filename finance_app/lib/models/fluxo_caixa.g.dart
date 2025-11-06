// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fluxo_caixa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FluxoCaixa _$FluxoCaixaFromJson(Map<String, dynamic> json) => FluxoCaixa(
  id: (json['id'] as num?)?.toInt(),
  idLoja: (json['id_loja'] as num).toInt(),
  idCategoria: (json['id_categoria'] as num).toInt(),
  descricao: json['descricao'] as String,
  valor: (json['valor'] as num).toDouble(),
  tipoFluxo: json['tipo_fluxo'] as String,
  cancelado: json['cancelado'] as bool?,
  confirmado: json['confirmado'] as bool?,
  dataCriacao:
      json['data_criacao'] == null
          ? null
          : DateTime.parse(json['data_criacao'] as String),
  dataVencimento:
      json['data_vencimento'] == null
          ? null
          : DateTime.parse(json['data_vencimento'] as String),
  diaVencimento: (json['dia_vencimento'] as num?)?.toInt(),
  repeticao: json['repeticao'] as String?,
  idRef: (json['id_ref'] as num?)?.toInt(),
);

Map<String, dynamic> _$FluxoCaixaToJson(FluxoCaixa instance) =>
    <String, dynamic>{
      'id': instance.id,
      'id_loja': instance.idLoja,
      'id_categoria': instance.idCategoria,
      'descricao': instance.descricao,
      'valor': instance.valor,
      'tipo_fluxo': instance.tipoFluxo,
      'cancelado': instance.cancelado,
      'confirmado': instance.confirmado,
      'data_criacao': instance.dataCriacao?.toIso8601String(),
      'data_vencimento': instance.dataVencimento?.toIso8601String(),
      'dia_vencimento': instance.diaVencimento,
      'repeticao': instance.repeticao,
      'id_ref': instance.idRef,
    };
