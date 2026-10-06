// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subcategoria.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subcategoria _$SubcategoriaFromJson(Map<String, dynamic> json) => Subcategoria(
  id: _$JsonConverterFromJson<int, int?>(
    json['id'],
    const IdConverter().fromJson,
  ),
  idCategoria: (json['id_categoria'] as num).toInt(),
  descricao: json['descricao'] as String,
  ativado: const AtivadoConverter().fromJson(json['ativado']),
  destaque: const AtivadoConverter().fromJson(json['destaque']),
  icone: json['icone'] as String?,
);

Map<String, dynamic> _$SubcategoriaToJson(Subcategoria instance) =>
    <String, dynamic>{
      'id': const IdConverter().toJson(instance.id),
      'id_categoria': instance.idCategoria,
      'descricao': instance.descricao,
      'ativado': const AtivadoConverter().toJson(instance.ativado),
      'destaque': const AtivadoConverter().toJson(instance.destaque),
      'icone': instance.icone,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);
