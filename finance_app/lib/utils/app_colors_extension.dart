import 'package:flutter/material.dart';

/// Cores semânticas que o [ColorScheme] do Material não tem slot para guardar:
/// status e meios de pagamento.
///
/// Ler daqui via `Theme.of(context).extension<AppColors>()!` evita o padrão
/// `isDark ? X : Y` espalhado pelas telas — o tema já entrega o valor certo.
///
/// ## Contraste
///
/// Todos os valores foram escolhidos por cálculo, não a olho, contra o **pior
/// fundo de cada modo**: `#E5E7EB` (o scaffold claro, mais escuro que o card
/// branco) e `#252B3B` (o card escuro, mais claro que o fundo `#0F1419`).
///
/// As cores de status batem ≥4.5:1 nos dois modos, o mínimo do WCAG para texto
/// normal — elas são usadas tanto como texto (valor de saldo, sangria) quanto
/// como tinta de ícone, e o limite de texto é o mais exigente dos dois. As cores
/// da paleta de pagamento identificam fatias do gráfico e ícones, não texto.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.serious,
    required this.error,
    required this.info,
    required this.paymentDinheiro,
    required this.paymentCredito,
    required this.paymentDebito,
    required this.paymentPix,
    required this.paymentTicket,
    required this.paymentOutras,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.series1,
    required this.series2,
    required this.series3,
  });

  /// Entrada de valor, caixa aberto, saldo positivo.
  final Color success;

  /// Atenção que não impede a operação.
  final Color warning;

  /// Entre [warning] e [error]: exige ação, mas ainda não falhou. Um boleto que
  /// vence hoje é o caso típico.
  final Color serious;

  /// Saída de valor, falha, sangria.
  final Color error;

  /// Informação neutra em destaque.
  final Color info;

  final Color paymentDinheiro;
  final Color paymentCredito;
  final Color paymentDebito;
  final Color paymentPix;
  final Color paymentTicket;
  final Color paymentOutras;

  /// O bloco parado do esqueleto de carregamento.
  final Color shimmerBase;

  /// O brilho que corre por cima do esqueleto.
  final Color shimmerHighlight;

  /// Séries dos gráficos de linha. Validadas como conjunto, comparando **todas**
  /// as combinações e não só as vizinhas — num gráfico de linhas o leitor vê as
  /// séries todas ao mesmo tempo. Substituíram um roxo/teal do Material 2 que
  /// não conversava com o azul da marca.
  final Color series1;
  final Color series2;
  final Color series3;

  /// A paleta de pagamento na ordem em que as fatias são desenhadas.
  ///
  /// A ordem importa: ela define quais cores ficam vizinhas no anel, e a
  /// separação entre vizinhas é o que sustenta a leitura sob daltonismo. Foi
  /// escolhida enumerando as ordenações possíveis e validando cada uma; não
  /// reordene sem revalidar.
  List<Color> get paymentPalette => [
    paymentDinheiro,
    paymentCredito,
    paymentDebito,
    paymentPix,
    paymentTicket,
    paymentOutras,
  ];

  /// Tema claro. Superfícies de referência: `#E5E7EB` (scaffold) e `#FFFFFF` (card).
  static const light = AppColors(
    success: Color(0xFF1C764C), // 4.52:1 sobre #E5E7EB
    warning: Color(0xFF9A580C), // 4.50:1
    serious: Color(0xFFAF481C), // 4.51:1
    error: Color(0xFFC1322D), // 4.51:1
    info: Color(0xFF2D66C1), // 4.51:1
    paymentDinheiro: Color(0xFF008300),
    paymentCredito: Color(0xFFE87BA4),
    paymentDebito: Color(0xFF2A78D6),
    paymentPix: Color(0xFF1BAF7A),
    paymentTicket: Color(0xFFEDA100),
    paymentOutras: Color(0xFF4A3AA7),
    shimmerBase: Color(0xFFE5E7EB),
    shimmerHighlight: Color(0xFFF3F4F6),
    series1: Color(0xFF2A78D6),
    series2: Color(0xFF008300),
    series3: Color(0xFFE87BA4),
  );

  /// Tema escuro. Superfícies de referência: `#0F1419` (fundo) e `#252B3B` (card).
  static const dark = AppColors(
    success: Color(0xFF27A56A), // 4.50:1 sobre #252B3B
    warning: Color(0xFFD77B11), // 4.50:1
    serious: Color(0xFFE17344), // 4.51:1
    error: Color(0xFFDD726E), // 4.52:1
    info: Color(0xFF6592DB), // 4.52:1
    paymentDinheiro: Color(0xFF008300),
    paymentCredito: Color(0xFFD55181),
    paymentDebito: Color(0xFF3987E5),
    paymentPix: Color(0xFF199E70),
    paymentTicket: Color(0xFFC98500),
    paymentOutras: Color(0xFF9085E9),
    shimmerBase: Color(0xFF2D3444),
    shimmerHighlight: Color(0xFF3A4356),
    series1: Color(0xFF3987E5),
    series2: Color(0xFF008300),
    series3: Color(0xFFD55181),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? serious,
    Color? error,
    Color? info,
    Color? paymentDinheiro,
    Color? paymentCredito,
    Color? paymentDebito,
    Color? paymentPix,
    Color? paymentTicket,
    Color? paymentOutras,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? series1,
    Color? series2,
    Color? series3,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      serious: serious ?? this.serious,
      error: error ?? this.error,
      info: info ?? this.info,
      paymentDinheiro: paymentDinheiro ?? this.paymentDinheiro,
      paymentCredito: paymentCredito ?? this.paymentCredito,
      paymentDebito: paymentDebito ?? this.paymentDebito,
      paymentPix: paymentPix ?? this.paymentPix,
      paymentTicket: paymentTicket ?? this.paymentTicket,
      paymentOutras: paymentOutras ?? this.paymentOutras,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      series1: series1 ?? this.series1,
      series2: series2 ?? this.series2,
      series3: series3 ?? this.series3,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      serious: Color.lerp(serious, other.serious, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      paymentDinheiro: Color.lerp(paymentDinheiro, other.paymentDinheiro, t)!,
      paymentCredito: Color.lerp(paymentCredito, other.paymentCredito, t)!,
      paymentDebito: Color.lerp(paymentDebito, other.paymentDebito, t)!,
      paymentPix: Color.lerp(paymentPix, other.paymentPix, t)!,
      paymentTicket: Color.lerp(paymentTicket, other.paymentTicket, t)!,
      paymentOutras: Color.lerp(paymentOutras, other.paymentOutras, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      series1: Color.lerp(series1, other.series1, t)!,
      series2: Color.lerp(series2, other.series2, t)!,
      series3: Color.lerp(series3, other.series3, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppColors &&
        other.success == success &&
        other.warning == warning &&
        other.serious == serious &&
        other.error == error &&
        other.info == info &&
        other.paymentDinheiro == paymentDinheiro &&
        other.paymentCredito == paymentCredito &&
        other.paymentDebito == paymentDebito &&
        other.paymentPix == paymentPix &&
        other.paymentTicket == paymentTicket &&
        other.paymentOutras == paymentOutras &&
        other.shimmerBase == shimmerBase &&
        other.shimmerHighlight == shimmerHighlight &&
        other.series1 == series1 &&
        other.series2 == series2 &&
        other.series3 == series3;
  }

  @override
  int get hashCode => Object.hash(
    success,
    warning,
    serious,
    error,
    info,
    paymentDinheiro,
    paymentCredito,
    paymentDebito,
    paymentPix,
    paymentTicket,
    paymentOutras,
    shimmerBase,
    shimmerHighlight,
    series1,
    series2,
    series3,
  );
}

/// Atalho para as cores semânticas: `context.appColors.success`.
extension AppColorsContext on BuildContext {
  /// Cai no padrão do modo atual quando um `Theme` aninhado não registra a
  /// extensão — alguns widgets do Material reconstroem o tema por conta
  /// própria, e uma cor errada é melhor que a tela inteira quebrar.
  AppColors get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light);
  }
}
