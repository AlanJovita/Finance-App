import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fluxo_caixa.g.dart';

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

/// Converte qualquer valor para String de forma segura.
String? _safeString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

@JsonSerializable(explicitToJson: true)
class FluxoCaixa {
  final int? id;
  @JsonKey(name: 'id_loja')
  final int? idLoja;
  @JsonKey(name: 'id_categoria')
  final int? idCategoria;

  /// Opcional: 0 quando o lançamento não usa subcategoria.
  @JsonKey(name: 'id_subcategoria')
  final int? idSubcategoria;
  final String? descricao;
  final double? valor;
  @JsonKey(name: 'tipo_fluxo')
  final String? tipoFluxo;
  final bool? cancelado;
  final bool? confirmado;
  @JsonKey(name: 'data_criacao')
  final DateTime? dataCriacao;
  @JsonKey(name: 'data_vencimento')
  final DateTime? dataVencimento;
  @JsonKey(name: 'dia_vencimento')
  final int? diaVencimento;
  final String? repeticao;
  @JsonKey(name: 'id_ref')
  final int? idRef;

  /// Conta bancária do lançamento; 0 é "sem conta", que é o padrão.
  ///
  /// `null` só aparece em objeto montado na mão sem o campo. No `toJson` isso é
  /// diferente de 0 e a API trata assim: chave ausente significa "não mexe na
  /// conta" no `PUT` (o PDV sincroniza sem o campo), enquanto 0 é o usuário
  /// escolhendo "sem conta". O formulário sempre manda um valor.
  @JsonKey(name: 'id_conta')
  final int? idConta;

  FluxoCaixa({
    this.id,
    this.idLoja,
    this.idCategoria,
    this.idSubcategoria,
    this.descricao,
    this.valor,
    this.tipoFluxo,
    this.cancelado,
    this.confirmado,
    this.dataCriacao,
    this.dataVencimento,
    this.diaVencimento,
    this.repeticao,
    this.idRef,
    this.idConta,
  });

  factory FluxoCaixa.fromJson(Map<String, dynamic> json) {
    try {
      return FluxoCaixa(
        id: _safeCast<int>(json['id']),
        idLoja: _safeCast<int>(json['id_cliente'] ?? json['id_loja']),
        idCategoria: _safeCast<int>(json['id_categoria']),
        idSubcategoria: _safeCast<int>(json['id_subcategoria']),
        descricao: _safeString(json['descricao']),
        valor: _safeCast<double>(json['valor']),
        tipoFluxo: _safeString(json['tipo_fluxo']),
        cancelado: json['cancelado'] as bool?,
        confirmado: json['confirmado'] as bool?,
        dataCriacao: _parseCustomDate(json['data_criacao']),
        dataVencimento: _parseCustomDate(json['data_vencimento']),
        diaVencimento: _safeCast<int>(json['dia_vencimento']),
        repeticao: _safeString(json['repeticao']),
        idRef: _safeCast<int>(json['id_ref']),
        idConta: _safeCast<int>(json['id_conta']),
      );
    } catch (e) {
      // `print`, e não o LoggerService: `fromJson` roda uma vez por item da
      // resposta, e uma lista malformada geraria uma linha de log remoto por
      // registro. O `rethrow` entrega o erro ao ApiService, que o registra uma
      // única vez com o endpoint e o corpo da resposta.
      debugPrint('Erro ao converter FluxoCaixa.fromJson: $e');
      debugPrint('JSON recebido: $json');
      rethrow;
    }
  }

  /// Converte datas no formato "d/M/yyyy" ou "--:--" para DateTime
  static DateTime? _parseCustomDate(dynamic value) {
    if (value == null) return null;
    final dateStr = value.toString().trim();

    // Verifica se é um formato inválido
    if (dateStr.isEmpty || dateStr == '--:--' || dateStr == '--') {
      return null;
    }

    // Tenta o parse padrão primeiro
    var date = DateTime.tryParse(dateStr);
    if (date != null) return date;

    // Tenta fazer parse dos formatos "d-M-yyyy" ou "d/M/yyyy"
    // (a API retorna datas como "d/M/yyyy")
    try {
      final parts = dateStr.split(dateStr.contains('/') ? '/' : '-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      debugPrint('Erro ao fazer parse da data: $dateStr - $e');
    }

    return null;
  }

  /// Cópia com campos trocados, para quem precisa alterar uma coisa só e
  /// mandar o registro inteiro de volta — o `UPDATE` da API reescreve todas as
  /// colunas, então omitir um campo o apagaria.
  ///
  /// Todo campo é anulável e `null` aqui significa "mantém o atual": não dá
  /// para limpar um campo por este caminho, e nenhum chamador precisa disso.
  FluxoCaixa copyWith({
    int? id,
    int? idLoja,
    int? idCategoria,
    int? idSubcategoria,
    String? descricao,
    double? valor,
    String? tipoFluxo,
    bool? cancelado,
    bool? confirmado,
    DateTime? dataCriacao,
    DateTime? dataVencimento,
    int? diaVencimento,
    String? repeticao,
    int? idRef,
    int? idConta,
  }) {
    return FluxoCaixa(
      id: id ?? this.id,
      idLoja: idLoja ?? this.idLoja,
      idCategoria: idCategoria ?? this.idCategoria,
      idSubcategoria: idSubcategoria ?? this.idSubcategoria,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      tipoFluxo: tipoFluxo ?? this.tipoFluxo,
      cancelado: cancelado ?? this.cancelado,
      confirmado: confirmado ?? this.confirmado,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      diaVencimento: diaVencimento ?? this.diaVencimento,
      repeticao: repeticao ?? this.repeticao,
      idRef: idRef ?? this.idRef,
      idConta: idConta ?? this.idConta,
    );
  }

  Map<String, dynamic> toJson() => _$FluxoCaixaToJson(this);

  /// Cópia pronta para nascer como lançamento **novo** — é o que o "Duplicar"
  /// do card entrega ao `FluxoFormDialog`.
  ///
  /// Quatro campos não são herdados, e cada um por um motivo:
  ///
  /// - **`id` e `id_ref` zerados.** Sem isso não é uma cópia, é a mesma linha:
  ///   o `id` mandaria a gravação para o `UPDATE` e o `id_ref` colaria o clone
  ///   num parcelamento alheio — onde ele apareceria como parcela e seria
  ///   alcançado pela replicação em grupo e pela exclusão do lote.
  /// - **`confirmado` em falso.** Duplicar uma conta já paga não paga a nova;
  ///   herdar a baixa registraria dinheiro que não se moveu, e o lojista
  ///   confirma depois, pelo botão do card.
  /// - **`repeticao` em "única vez"**, junto com o sufixo `[3/12]` fora da
  ///   descrição. Clonar *uma parcela* não é clonar o lote: o formulário
  ///   libera a repetição para quem quiser parcelar de novo, mas em 1 o gesto
  ///   gera um lançamento, não doze.
  ///
  /// O vencimento é **hoje**, não o do original: o uso real é "isto outra
  /// vez", e copiar a data faria o clone de uma conta de agosto nascer
  /// atrasado, em vermelho, esperando que alguém trocasse a data toda vez. A
  /// data continua a um toque no chip do cabeçalho do modal. Lançamento sem
  /// vencimento também recebe hoje — o formulário não sabe gravar "sem data"
  /// de qualquer forma.
  ///
  /// [hoje] é injetável para o teste não depender do calendário da máquina.
  FluxoCaixa paraClone({DateTime? hoje}) {
    final agora = hoje ?? DateTime.now();
    final vencimento = DateTime(agora.year, agora.month, agora.day);

    return FluxoCaixa(
      id: 0,
      idLoja: idLoja,
      idCategoria: idCategoria,
      idSubcategoria: idSubcategoria,
      descricao: semSufixoParcela(descricao),
      valor: valor,
      tipoFluxo: tipoFluxo,
      cancelado: false,
      confirmado: false,
      dataCriacao: vencimento,
      dataVencimento: vencimento,
      diaVencimento: vencimento.day,
      repeticao: '1',
      idRef: 0,
      idConta: idConta,
    );
  }

  /// Tira o `[3/12]` do fim da descrição, se houver.
  ///
  /// O sufixo é escrito pelo `FluxoFormDialog` ao criar um parcelamento, uma
  /// parcela por POST, e identifica a posição da linha dentro do lote. Num
  /// clone ele seria uma afirmação falsa: o lançamento novo não é a terceira
  /// parcela de nada.
  static String? semSufixoParcela(String? descricao) {
    if (descricao == null) return null;

    return descricao.replaceFirst(RegExp(r'\s*\[\d+/\d+\]\s*$'), '').trim();
  }
}
