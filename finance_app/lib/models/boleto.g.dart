// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boleto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Boleto _$BoletoFromJson(Map<String, dynamic> json) => Boleto(
  status: json['status'] as String,
  dueDate: json['dueDate'] as String,
  invoiceUrl: json['invoiceUrl'] as String,
);

Map<String, dynamic> _$BoletoToJson(Boleto instance) => <String, dynamic>{
  'status': instance.status,
  'dueDate': instance.dueDate,
  'invoiceUrl': instance.invoiceUrl,
};
