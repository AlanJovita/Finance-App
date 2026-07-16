// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categoria.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Categoria _$CategoriaFromJson(Map<String, dynamic> json) => Categoria(
  id: _$JsonConverterFromJson<int, int?>(
    json['id'],
    const IdConverter().fromJson,
  ),
  idLoja: (Categoria._readIdLoja(json, 'id_loja') as num).toInt(),
  descricao: json['descricao'] as String,
  ativado: const AtivadoConverter().fromJson(json['ativado']),
  tipoFluxo: (json['tipo_fluxo'] as num).toInt(),
);

Map<String, dynamic> _$CategoriaToJson(Categoria instance) => <String, dynamic>{
  'id': const IdConverter().toJson(instance.id),
  'id_loja': instance.idLoja,
  'descricao': instance.descricao,
  'ativado': const AtivadoConverter().toJson(instance.ativado),
  'tipo_fluxo': instance.tipoFluxo,
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);
