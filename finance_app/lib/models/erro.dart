class Erro {
  final int idLog;
  final int idCliente;
  final String data;
  final String descricao;
  final String versao;
  final String classe;
  final String metodo;
  final int linha;
  final int qtd;
  final int status;
  final int classificacao;
  final int origem;
  final int idUsuarioLocal;
  final int idComputadorLocal;

  Erro({
    required this.idLog,
    required this.idCliente,
    required this.data,
    required this.descricao,
    required this.versao,
    required this.classe,
    required this.metodo,
    required this.linha,
    required this.qtd,
    required this.status,
    required this.classificacao,
    required this.origem,
    required this.idUsuarioLocal,
    required this.idComputadorLocal,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_log': idLog,
      'id_cliente': idCliente,
      'data': data,
      'descricao': descricao,
      'versao': versao,
      'classe': classe,
      'metodo': metodo,
      'linha': linha,
      'qtd': qtd,
      'status': status,
      'classificacao': classificacao,
      'origem': origem,
      'id_usuario_local': idUsuarioLocal,
      'id_computador_local': idComputadorLocal,
    };
  }

  factory Erro.fromJson(Map<String, dynamic> json) {
    return Erro(
      idLog: json['id_log'] as int,
      idCliente: json['id_cliente'] as int,
      data: json['data'] as String,
      descricao: json['descricao'] as String,
      versao: json['versao'] as String,
      classe: json['classe'] as String,
      metodo: json['metodo'] as String,
      linha: json['linha'] as int,
      qtd: json['qtd'] as int,
      status: json['status'] as int,
      classificacao: json['classificacao'] as int,
      origem: json['origem'] as int,
      idUsuarioLocal: json['id_usuario_local'] as int,
      idComputadorLocal: json['id_computador_local'] as int,
    );
  }
}
