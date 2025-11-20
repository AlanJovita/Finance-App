class Evento {
  final int idCliente;
  final String data;
  final String descricao;
  final int origem;
  final int idUsuarioLocal;

  Evento({
    required this.idCliente,
    required this.data,
    required this.descricao,
    required this.origem,
    required this.idUsuarioLocal,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_cliente': idCliente,
      'data': data,
      'descricao': descricao,
      'origem': origem,
      'id_usuario_local': idUsuarioLocal,
    };
  }

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      idCliente: json['id_cliente'] as int,
      data: json['data'] as String,
      descricao: json['descricao'] as String,
      origem: json['origem'] as int,
      idUsuarioLocal: json['id_usuario_local'] as int,
    );
  }
}
