// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categoria.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Categoria _$CategoriaFromJson(Map<String, dynamic> json) => Categoria(
  id: (json['id'] as num?)?.toInt(),
  idLoja: (json['id_loja'] as num).toInt(),
  descricao: json['descricao'] as String,
  ativado: json['ativado'] as bool?,
  tipoFluxo: json['tipo_fluxo'] as String,
);

Map<String, dynamic> _$CategoriaToJson(Categoria instance) => <String, dynamic>{
  'id': instance.id,
  'id_loja': instance.idLoja,
  'descricao': instance.descricao,
  'ativado': instance.ativado,
  'tipo_fluxo': instance.tipoFluxo,
};
