import 'package:flutter/services.dart';

import 'currency_formatter.dart';

/// Máscara monetária que preenche o campo a partir dos centavos.
///
/// Cada dígito digitado empurra o valor uma casa para a esquerda — `1` vira
/// `0,01`, `12` vira `0,12`, `123` vira `1,23` — então o usuário nunca precisa
/// digitar a vírgula nem o separador de milhar, que aparecem sozinhos.
///
/// O cursor fica sempre no fim: como a digitação só acrescenta à direita,
/// deixá-lo onde o toque caiu permitiria inserir um dígito no meio do número já
/// formatado, e a posição anterior deixa de existir depois da remontagem.
class CurrencyInputFormatter extends TextInputFormatter {
  /// Teto de dígitos, centavos inclusos. 11 chega a R$ 999.999.999,99 —
  /// confortavelmente acima do `decimal(11,2)` da coluna `valor`.
  final int maxDigitos;

  const CurrencyInputFormatter({this.maxDigitos = 11});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Zeros à esquerda não têm significado aqui, e descartá-los é o que permite
    // apagar o campo: sem isso "0,01" travaria em "0,00" no backspace, porque
    // os zeros restantes continuariam formatando para o mesmo texto.
    final digitos = newValue.text
        .replaceAll(RegExp(r'[^0-9]'), '')
        .replaceFirst(RegExp(r'^0+'), '');

    if (digitos.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Estourou o teto: devolve o valor anterior, para o campo simplesmente
    // parar de aceitar em vez de truncar pelo lado errado.
    if (digitos.length > maxDigitos) return oldValue;

    final texto = CurrencyFormatter.formatValue(int.parse(digitos) / 100);

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
