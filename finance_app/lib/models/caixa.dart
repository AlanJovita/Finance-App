import 'package:json_annotation/json_annotation.dart';

part 'caixa.g.dart';

/// Tenta converter um valor para [T] (int ou double) de forma segura.
/// Retorna null se o valor for nulo ou a conversão falhar.
T? _safeCast<T extends num>(dynamic value) {
  if (value == null) return null;
  if (value is T) return value;
  if (value is num) {
    if (T == int) {
      return value.toInt() as T?;
    } else if (T == double) {
      return value.toDouble() as T?;
    }
  }
  if (value is String) {
    if (T == int) {
      return int.tryParse(value) as T?;
    } else if (T == double) {
      return double.tryParse(value) as T?;
    }
  }
  return null;
}

@JsonSerializable()
class Caixa {
  final int? id;
  @JsonKey(name: 'id_loja')
  final int idLoja;
  @JsonKey(name: 'nome_loja')
  final String? nomeLoja;
  @JsonKey(name: 'id_caixa')
  final int? idCaixa;
  @JsonKey(name: 'id_usuario')
  final int idUsuario;
  @JsonKey(name: 'id_ref_repeticao')
  final int? idRefRepeticao;
  final double? troco;
  @JsonKey(name: 'data_abertura')
  final DateTime? dataAbertura;
  @JsonKey(name: 'data_fechamento')
  final DateTime? dataFechamento;
  final double? saldo;
  @JsonKey(name: 'status_caixa')
  final int? statusCaixa;
  @JsonKey(name: 'saldo_dinheiro')
  final double? saldoDinheiro;
  @JsonKey(name: 'saldo_cartao')
  final double? saldoCartao;
  @JsonKey(name: 'saldo_outras')
  final double? saldoOutras;
  @JsonKey(name: 'saldo_pix')
  final double? saldoPix;
  @JsonKey(name: 'saldo_ticket')
  final double? saldoTicket;
  final double? sangria;
  final double? suprimento;
  @JsonKey(name: 'saldo_px_caixa')
  final double? saldoPxCaixa;
  @JsonKey(name: 'saldo_nao_faturado')
  final double? saldoNaoFaturado;
  @JsonKey(name: 'total_pedido_confirmado')
  final int? totalPedidoConfirmado;
  @JsonKey(name: 'total_pedido_estornado')
  final int? totalPedidoEstornado;

  Caixa({
    this.id,
    required this.idLoja,
    this.nomeLoja,
    this.idCaixa,
    required this.idUsuario,
    this.idRefRepeticao,
    this.troco,
    this.dataAbertura,
    this.dataFechamento,
    this.saldo,
    this.statusCaixa,
    this.saldoDinheiro,
    this.saldoCartao,
    this.saldoOutras,
    this.saldoPix,
    this.saldoTicket,
    this.sangria,
    this.suprimento,
    this.saldoPxCaixa,
    this.saldoNaoFaturado,
    this.totalPedidoConfirmado,
    this.totalPedidoEstornado,
  });

  /// Construtor de fábrica seguro que lida com erros de conversão de tipo.
  factory Caixa.fromJson(Map<String, dynamic> json) {
    try {
      return Caixa(
        id: _safeCast<int>(json['id']),
        idLoja: _safeCast<int>(json['id_loja']) ?? 0, // Campo obrigatório
        nomeLoja: json['nome_loja'] as String?,
        idCaixa: _safeCast<int>(json['id_caixa']),
        idUsuario: _safeCast<int>(json['id_usuario']) ?? 0, // Campo obrigatório
        idRefRepeticao: _safeCast<int>(json['id_ref_repeticao']),
        troco: _safeCast<double>(json['troco']),
        dataAbertura:
            json['data_abertura'] == null
                ? null
                : DateTime.tryParse(json['data_abertura'] as String? ?? ''),
        dataFechamento:
            json['data_fechamento'] == null
                ? null
                : DateTime.tryParse(json['data_fechamento'] as String? ?? ''),
        saldo: _safeCast<double>(json['saldo']),
        statusCaixa: _safeCast<int>(json['status_caixa']),
        saldoDinheiro: _safeCast<double>(json['saldo_dinheiro']),
        saldoCartao: _safeCast<double>(json['saldo_cartao']),
        saldoOutras: _safeCast<double>(json['saldo_outras']),
        saldoPix: _safeCast<double>(json['saldo_pix']),
        saldoTicket: _safeCast<double>(json['saldo_ticket']),
        sangria: _safeCast<double>(json['sangria']),
        suprimento: _safeCast<double>(json['suprimento']),
        saldoPxCaixa: _safeCast<double>(json['saldo_px_caixa']),
        saldoNaoFaturado: _safeCast<double>(json['saldo_nao_faturado']),
        totalPedidoConfirmado: _safeCast<int>(json['total_pedido_confirmado']),
        totalPedidoEstornado: _safeCast<int>(json['total_pedido_estornado']),
      );
    } catch (e) {
      // Adicione aqui um log do erro se desejar (ex: print, logger, etc.)
      // print('Erro ao desserializar Caixa: $e');
      // Lança uma exceção mais informativa para a camada que chamou.
      throw FormatException(
        'Falha ao converter o JSON para o modelo Caixa: $e',
      );
    }
  }

  Map<String, dynamic> toJson() => _$CaixaToJson(this);

  /// Payload para POST /finance/caixa: o Caixa.from_dict da api-master só lê
  /// chaves maiúsculas legadas (DATA_ABERTURA, STATUS_CAIXA...) ou os nomes
  /// curtos do PDV — as chaves de [toJson] (data_abertura...) não são aceitas.
  Map<String, dynamic> toApiJson() => {
    'ID_CLIENTE': idLoja,
    'ID_CAIXA': idCaixa,
    'ID_USUARIO': idUsuario,
    'ID_REF_REPETICAO': idRefRepeticao ?? 0,
    'TROCO': troco ?? 0.0,
    'DATA_ABERTURA': dataAbertura?.toIso8601String(),
    'DATA_FECHAMENTO': dataFechamento?.toIso8601String(),
    'SALDO': saldo ?? 0.0,
    'STATUS_CAIXA': statusCaixa ?? 0,
    'SALDO_DINHEIRO': saldoDinheiro ?? 0.0,
    'SALDO_CARTAO': saldoCartao ?? 0.0,
    'SALDO_OUTRAS': saldoOutras ?? 0.0,
    'SALDO_PIX': saldoPix ?? 0.0,
    'SALDO_TICKET': saldoTicket ?? 0.0,
    'SANGRIA': sangria ?? 0.0,
    'SUPRIMENTO': suprimento ?? 0.0,
    'SALDO_PX_CAIXA': saldoPxCaixa ?? 0.0,
    'SALDO_NAO_FATURADO': saldoNaoFaturado ?? 0.0,
    // Estas duas a API só lê em minúsculas
    'total_pedido_confirmado': totalPedidoConfirmado ?? 0,
    'total_pedido_estornado': totalPedidoEstornado ?? 0,
  };
}
