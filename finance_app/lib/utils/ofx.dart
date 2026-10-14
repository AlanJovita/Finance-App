import 'dart:convert';

/// Leitor de extrato OFX de **cartão de crédito**.
///
/// Escrito à mão, e não com pacote: os leitores de OFX no pub ou estão
/// abandonados ou só entendem OFX 2 (XML de verdade). O que os bancos
/// brasileiros exportam é OFX 1.x, que é **SGML** — cabeçalho em
/// `CHAVE:valor` antes do `<OFX>`, e tag de folha que pode ou não vir fechada.
/// O Nubank fecha (`<TRNAMT>-108.99</TRNAMT>`); outros bancos não
/// (`<TRNAMT>-108.99`), e um parser de XML quebra no segundo caso.
///
/// Daí a leitura por tag tolerante: o valor de uma tag é o que vem depois dela
/// até o próximo `<`. Serve para as duas formas e não depende de o arquivo ser
/// bem formado.
class ExtratoOfx {
  /// `<ORG>` do bloco de instituição — "NU PAGAMENTOS S.A.".
  final String instituicao;

  /// `<ACCTID>`. No Nubank é um UUID, não o número do cartão: serve para
  /// reconhecer o mesmo cartão num próximo arquivo, nunca para identificar o
  /// cadastro na primeira importação.
  final String conta;

  /// Período que o arquivo cobre (`DTSTART`/`DTEND`). No cartão é o ciclo da
  /// fatura, e é o que permite avisar quando o `dia_fechamento` cadastrado não
  /// corresponde ao do extrato.
  final DateTime? inicio;
  final DateTime? fim;

  /// `LEDGERBAL/BALAMT` — o saldo que o banco afirma, em módulo.
  ///
  /// Serve de conferência na tela, não de validação: neste arquivo ele fecha
  /// com a soma dos débitos a menos de um centavo, e um centavo de divergência
  /// não é motivo para recusar a importação inteira.
  final double? saldo;

  final List<LancamentoOfx> lancamentos;

  /// Quantas linhas `<STMTTRN>` foram descartadas por não ter data ou valor
  /// legível. Aparece na tela: silenciar isso esconderia lançamento faltando.
  final int ignorados;

  const ExtratoOfx({
    required this.instituicao,
    required this.conta,
    required this.inicio,
    required this.fim,
    required this.saldo,
    required this.lancamentos,
    required this.ignorados,
  });

  /// Lê os bytes do arquivo escolhido.
  ///
  /// O encoding vem do cabeçalho (`CHARSET:1252`), mas não se pode confiar
  /// nele: há banco que declara 1252 e escreve UTF-8. Então a tentativa é
  /// UTF-8 estrito primeiro — se o arquivo for Latin-1 com acento, `utf8`
  /// estoura e a segunda tentativa resolve. Fazer o contrário (latin1 sempre)
  /// transformaria "Educação" em "EducaÃ§Ã£o" em todo arquivo moderno.
  static ExtratoOfx deBytes(List<int> bytes) {
    String texto;
    try {
      texto = utf8.decode(bytes);
    } on FormatException {
      texto = latin1.decode(bytes, allowInvalid: true);
    }

    return deTexto(texto);
  }

  static ExtratoOfx deTexto(String texto) {
    if (!texto.toUpperCase().contains('<OFX')) {
      throw const OfxInvalidoException(
        'O arquivo não parece ser um OFX. Baixe o extrato em OFX no aplicativo '
        'do banco.',
      );
    }

    // Conta bancária tem outro domínio no app (lançamentos do caixa, não
    // fatura), e importá-la como cartão criaria compras numa fatura que não
    // existe. Recusar com o motivo é melhor que importar errado.
    final ehCartao =
        _tem(texto, 'CREDITCARDMSGSRSV1') || _tem(texto, 'CCSTMTRS');
    if (!ehCartao) {
      final ehConta = _tem(texto, 'BANKMSGSRSV1') || _tem(texto, 'STMTRS');
      throw OfxInvalidoException(
        ehConta
            ? 'Este OFX é de conta bancária, não de cartão de crédito. '
                'Baixe o extrato da fatura do cartão.'
            : 'Não encontrei um extrato de cartão de crédito neste arquivo.',
      );
    }

    final lancamentos = <LancamentoOfx>[];
    var ignorados = 0;

    for (final bloco in _blocos(texto, 'STMTTRN')) {
      final data = _data(_tag(bloco, 'DTPOSTED'));
      final valor = _valor(_tag(bloco, 'TRNAMT'));

      // Sem data não há fatura em que cair; sem valor não há lançamento. As
      // duas coisas são o mínimo, e uma linha sem elas é defeito do arquivo.
      if (data == null || valor == null || valor == 0) {
        ignorados++;
        continue;
      }

      lancamentos.add(
        LancamentoOfx(
          data: data,
          // O app guarda valor absoluto e o sinal em `tipo_fluxo`; no OFX o
          // sinal está no número (compra negativa, crédito positivo).
          valor: valor.abs(),
          credito:
              valor > 0 ||
              (_tag(bloco, 'TRNTYPE') ?? '').toUpperCase() == 'CREDIT',
          descricao: _descricao(bloco),
          fitid: (_tag(bloco, 'FITID') ?? '').trim(),
        ),
      );
    }

    if (lancamentos.isEmpty) {
      throw const OfxInvalidoException(
        'O arquivo não tem nenhum lançamento legível.',
      );
    }

    return ExtratoOfx(
      instituicao: (_tag(texto, 'ORG') ?? '').trim(),
      conta: (_tag(texto, 'ACCTID') ?? '').trim(),
      inicio: _data(_tag(texto, 'DTSTART')),
      fim: _data(_tag(texto, 'DTEND')),
      saldo: _valor(_tag(texto, 'BALAMT'))?.abs(),
      lancamentos: lancamentos,
      ignorados: ignorados,
    );
  }

  /// Soma dos débitos — o total de compras do arquivo, para conferir com o
  /// [saldo] que o banco declara.
  double get totalDebitos => lancamentos
      .where((l) => !l.credito)
      .fold(0.0, (soma, l) => soma + l.valor);

  static bool _tem(String texto, String tag) =>
      texto.toUpperCase().contains('<$tag');

  /// Conteúdo da primeira ocorrência de [tag]: o que vem depois dela até o
  /// próximo `<`. Cobre a tag fechada e a não fechada de uma vez.
  static String? _tag(String texto, String tag) {
    final m = RegExp('<$tag>([^<]*)', caseSensitive: false).firstMatch(texto);
    return m?.group(1);
  }

  /// Os blocos de uma tag repetida (`STMTTRN`).
  ///
  /// Vai de uma abertura até o fechamento **ou** até a abertura seguinte —
  /// arquivo sem `</STMTTRN>` é comum, e fatiar só pelo fechamento devolveria
  /// um bloco gigante com todas as transações dentro.
  static Iterable<String> _blocos(String texto, String tag) {
    final abre = RegExp('<$tag>', caseSensitive: false);
    final fecha = RegExp('</$tag>', caseSensitive: false);
    final inicios = abre.allMatches(texto).map((m) => m.end).toList();

    return [
      for (var i = 0; i < inicios.length; i++)
        () {
          final proximo =
              i + 1 < inicios.length ? inicios[i + 1] : texto.length;
          final fim = fecha.firstMatch(texto.substring(inicios[i], proximo));
          return texto.substring(
            inicios[i],
            fim == null ? proximo : inicios[i] + fim.start,
          );
        }(),
    ];
  }

  /// `MEMO`, com `NAME` de reserva — alguns bancos põem o estabelecimento num,
  /// alguns no outro. Cortado em 200 para caber na coluna da API.
  static String _descricao(String bloco) {
    final bruto = (_tag(bloco, 'MEMO') ?? _tag(bloco, 'NAME') ?? '').trim();
    final limpo = bruto.replaceAll(RegExp(r'\s+'), ' ');
    if (limpo.isEmpty) return 'Lançamento importado';

    return limpo.length <= 200 ? limpo : limpo.substring(0, 200);
  }

  /// `20261014000000[-3:BRT]` → 14/10/2026.
  ///
  /// Só os 8 primeiros dígitos interessam. A hora é sempre 000000 nos extratos
  /// brasileiros, e **o fuso é descartado de propósito**: aplicá-lo moveria a
  /// meia-noite para as 21h do dia anterior, e a data da compra passaria a ser
  /// o dia errado — inclusive mudando de fatura quando a compra cai no dia do
  /// fechamento.
  static DateTime? _data(String? bruto) {
    if (bruto == null) return null;

    final digitos = RegExp(r'\d{8}').firstMatch(bruto.trim())?.group(0);
    if (digitos == null) return null;

    final ano = int.tryParse(digitos.substring(0, 4));
    final mes = int.tryParse(digitos.substring(4, 6));
    final dia = int.tryParse(digitos.substring(6, 8));
    if (ano == null || mes == null || dia == null) return null;
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;

    return DateTime(ano, mes, dia);
  }

  /// `-108.99`, e também `-1.234,56` de quem exporta no formato brasileiro.
  static double? _valor(String? bruto) {
    if (bruto == null) return null;

    var texto = bruto.trim().replaceAll(RegExp(r'[^\d,.\-+]'), '');
    if (texto.isEmpty) return null;

    final temVirgula = texto.contains(',');
    final temPonto = texto.contains('.');

    if (temVirgula && temPonto) {
      // "1.234,56": ponto é milhar, vírgula é decimal.
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    } else if (temVirgula) {
      texto = texto.replaceAll(',', '.');
    }

    return double.tryParse(texto);
  }
}

/// Uma transação do extrato, já normalizada para o que o app entende.
class LancamentoOfx {
  final DateTime data;

  /// Sempre positivo: o sinal do OFX virou [credito].
  final double valor;

  /// Crédito no cartão (pagamento, estorno, cashback). `false` é compra.
  final bool credito;

  final String descricao;

  /// `FITID`. **Não serve sozinho como chave**: no extrato do Nubank o IOF de
  /// uma compra internacional repete o `FITID` da compra que o gerou — dois
  /// lançamentos legítimos com o mesmo id. Deduplicar só por ele descartaria o
  /// IOF em silêncio.
  final String fitid;

  const LancamentoOfx({
    required this.data,
    required this.valor,
    required this.credito,
    required this.descricao,
    required this.fitid,
  });

  /// Parece o pagamento da fatura?
  ///
  /// Pagamento **não pode** entrar como movimento: a API recusa
  /// (`"Pagamento de fatura deve ser registrado pela fatura"`) porque é ele que
  /// dá baixa na despesa da fatura no caixa. Importá-lo como estorno abateria o
  /// saldo devedor sem contrapartida nenhuma no caixa — o dinheiro sairia do
  /// cartão e desapareceria.
  ///
  /// A detecção é pelo texto porque o OFX não tem campo para isso: `TRNTYPE` só
  /// diz "CREDIT", igual a um estorno.
  bool get parecePagamentoDeFatura =>
      credito && RegExp(r'pagament', caseSensitive: false).hasMatch(descricao);

  /// O "Parcela 5/12" que o banco escreve no MEMO, quando escreve.
  ///
  /// É informação, não instrução: ver `ItemImportacaoOfx` para por que o
  /// importador nunca transforma isso em parcelamento de verdade.
  String? get parcela => RegExp(
    r'parcela\s*(\d+\s*/\s*\d+)',
    caseSensitive: false,
  ).firstMatch(descricao)?.group(1)?.replaceAll(' ', '');
}

/// Arquivo que não serve para importar, com o motivo pronto para a tela.
class OfxInvalidoException implements Exception {
  final String motivo;

  const OfxInvalidoException(this.motivo);

  @override
  String toString() => motivo;
}
