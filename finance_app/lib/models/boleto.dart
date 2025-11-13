import 'package:json_annotation/json_annotation.dart';

part 'boleto.g.dart';

@JsonSerializable()
class Boleto {
  final String status;
  final String dueDate;
  final String invoiceUrl;

  Boleto({
    required this.status,
    required this.dueDate,
    required this.invoiceUrl,
  });

  factory Boleto.fromJson(Map<String, dynamic> json) => _$BoletoFromJson(json);
  Map<String, dynamic> toJson() => _$BoletoToJson(this);

  bool get isOverdue => status == 'OVERDUE';
  bool get isPending => status == 'PENDING';

  DateTime get dueDateParsed => DateTime.parse(dueDate);
}
