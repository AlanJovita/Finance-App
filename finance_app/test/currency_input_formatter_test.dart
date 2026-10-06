import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/utils/currency_formatter.dart';
import 'package:finance_app/utils/currency_input_formatter.dart';

void main() {
  const formatter = CurrencyInputFormatter();

  /// Simula a digitação tecla a tecla, passando cada estado pelo formatador —
  /// é assim que o campo se comporta de verdade.
  String digitar(String teclas, {String inicial = ''}) {
    var atual = TextEditingValue(
      text: inicial,
      selection: TextSelection.collapsed(offset: inicial.length),
    );

    for (final tecla in teclas.split('')) {
      final digitado = TextEditingValue(
        text: atual.text + tecla,
        selection: TextSelection.collapsed(offset: atual.text.length + 1),
      );
      atual = formatter.formatEditUpdate(atual, digitado);
    }

    return atual.text;
  }

  /// Simula um backspace sobre o texto já formatado.
  String apagar(String texto) {
    final atual = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
    final apagado = TextEditingValue(
      text: texto.substring(0, texto.length - 1),
      selection: TextSelection.collapsed(offset: texto.length - 1),
    );
    return formatter.formatEditUpdate(atual, apagado).text;
  }

  group('digitação a partir dos centavos', () {
    test('cada dígito empurra o valor uma casa para a esquerda', () {
      expect(digitar('1'), '0,01');
      expect(digitar('12'), '0,12');
      expect(digitar('123'), '1,23');
      expect(digitar('1234'), '12,34');
      expect(digitar('12345'), '123,45');
    });

    test('o separador de milhar aparece sozinho', () {
      expect(digitar('123456'), '1.234,56');
      expect(digitar('123456789'), '1.234.567,89');
      expect(digitar('12345678901'), '123.456.789,01');
    });

    test('o usuário não precisa digitar vírgula nem ponto', () {
      expect(digitar('1.2,3'), '1,23', reason: 'pontuação digitada é ignorada');
    });

    test('zeros à esquerda não contam', () {
      expect(digitar('0'), '');
      expect(digitar('000'), '');
      expect(digitar('0005'), '0,05');
    });
  });

  group('limites', () {
    test('para de aceitar depois do teto de dígitos', () {
      // 11 dígitos é o máximo; o 12º não entra.
      expect(digitar('123456789012'), '123.456.789,01');
    });

    test('o teto é configurável', () {
      const curto = CurrencyInputFormatter(maxDigitos: 4);
      final atual = TextEditingValue(text: '12,34');
      final novo = TextEditingValue(text: '12,345');

      expect(curto.formatEditUpdate(atual, novo).text, '12,34');
    });
  });

  group('apagar', () {
    test('o backspace desfaz dígito a dígito', () {
      expect(apagar('1.234,56'), '123,45');
      expect(apagar('123,45'), '12,34');
      expect(apagar('12,34'), '1,23');
      expect(apagar('1,23'), '0,12');
      expect(apagar('0,12'), '0,01');
    });

    test('apagar o último dígito esvazia o campo', () {
      // Sem descartar zeros à esquerda, "0,01" travaria em "0,00".
      expect(apagar('0,01'), '');
    });
  });

  group('cursor', () {
    test('fica sempre no fim do texto', () {
      final resultado = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '123'),
      );

      expect(resultado.text, '1,23');
      expect(resultado.selection.baseOffset, resultado.text.length);
    });
  });

  group('CurrencyFormatter.parse', () {
    test('desfaz a máscara', () {
      expect(CurrencyFormatter.parse('1.234,56'), 1234.56);
      expect(CurrencyFormatter.parse('0,01'), 0.01);
      expect(CurrencyFormatter.parse('123.456.789,01'), 123456789.01);
    });

    test('o ponto é milhar, não decimal', () {
      // Ler "1.234" como 1.234 gravaria um centavo e meio no lugar de mil reais.
      expect(CurrencyFormatter.parse('1.234,00'), 1234.0);
    });

    test('sem dígito nenhum devolve null', () {
      expect(CurrencyFormatter.parse(''), isNull);
      expect(CurrencyFormatter.parse(null), isNull);
      expect(CurrencyFormatter.parse('R\$ ,.'), isNull);
    });

    test('faz o caminho de volta do que formatValue escreveu', () {
      for (final valor in [0.01, 1.0, 12.34, 1234.56, 999999999.99]) {
        expect(
          CurrencyFormatter.parse(CurrencyFormatter.formatValue(valor)),
          valor,
          reason: 'ida e volta de $valor',
        );
      }
    });
  });
}
