/// Utilitário para formatação de valores monetários no padrão brasileiro
class CurrencyFormatter {
  /// Formata um valor double para o padrão brasileiro (R$ X.XXX,XX)
  ///
  /// Exemplo: 1234.56 -> "R$ 1.234,56"
  static String format(double? value) {
    if (value == null) return 'R\$ 0,00';

    final valueStr = value.toStringAsFixed(2);
    final parts = valueStr.split('.');

    // Parte inteira com separador de milhares
    String integerPart = parts[0];
    String formattedInteger = '';

    for (int i = integerPart.length - 1; i >= 0; i--) {
      formattedInteger = integerPart[i] + formattedInteger;
      if ((integerPart.length - i) % 3 == 0 && i != 0) {
        formattedInteger = '.$formattedInteger';
      }
    }

    // Parte decimal
    final decimalPart = parts[1];

    return 'R\$ $formattedInteger,$decimalPart';
  }

  /// Formata apenas o valor sem o símbolo R$
  ///
  /// Exemplo: 1234.56 -> "1.234,56"
  static String formatValue(double? value) {
    if (value == null) return '0,00';

    final valueStr = value.toStringAsFixed(2);
    final parts = valueStr.split('.');

    // Parte inteira com separador de milhares
    String integerPart = parts[0];
    String formattedInteger = '';

    for (int i = integerPart.length - 1; i >= 0; i--) {
      formattedInteger = integerPart[i] + formattedInteger;
      if ((integerPart.length - i) % 3 == 0 && i != 0) {
        formattedInteger = '.$formattedInteger';
      }
    }

    // Parte decimal
    final decimalPart = parts[1];

    return '$formattedInteger,$decimalPart';
  }

  /// Formata valores simplificados (apenas substitui ponto por vírgula)
  ///
  /// Exemplo: 1234.56 -> "1234,56"
  static String formatSimple(double? value, {int decimals = 2}) {
    if (value == null) return '0${"," + "0" * decimals}';
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }
}
