import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/utils/categoria_visuais.dart';

void main() {
  group('cor', () {
    test('converte #RRGGBB em cor opaca', () {
      expect(CategoriaVisuais.cor('#E53935'), const Color(0xFFE53935));
      expect(CategoriaVisuais.cor('E53935'), const Color(0xFFE53935));
    });

    test('cai na cor padrão quando o registro está torto', () {
      final padrao = CategoriaVisuais.cor(CategoriaVisuais.corPadrao);

      for (final entrada in [null, '', 'azul', '#12', '#GGGGGG']) {
        expect(
          CategoriaVisuais.cor(entrada),
          padrao,
          reason: 'entrada ${entrada ?? "nula"} não pode derrubar a tela',
        );
      }
    });

    test('toda cor da paleta é válida', () {
      final padrao = CategoriaVisuais.cor(CategoriaVisuais.corPadrao);
      // A única que pode ser igual ao padrão é a própria.
      for (final cor in CategoriaVisuais.paleta) {
        if (cor.hex == CategoriaVisuais.corPadrao) continue;
        expect(CategoriaVisuais.cor(cor.hex), isNot(padrao), reason: cor.nome);
      }
    });
  });

  group('icone', () {
    test('nome desconhecido, vazio ou nulo cai no genérico', () {
      for (final nome in [null, '', 'nao_existe']) {
        expect(CategoriaVisuais.icone(nome), CategoriaVisuais.iconeGenerico);
      }
    });

    test('resolve um nome do catálogo', () {
      expect(CategoriaVisuais.icone('shopping_cart'), Icons.shopping_cart);
    });

    test('todo ícone sugerido existe no catálogo', () {
      for (final nome in CategoriaVisuais.iconesSugeridos) {
        expect(
          CategoriaVisuais.catalogo.containsKey(nome),
          isTrue,
          reason: '$nome é sugerido mas não está no catálogo',
        );
      }
    });
  });

  group('buscarIcones', () {
    test('termo vazio devolve tudo, com os sugeridos à frente', () {
      final todos = CategoriaVisuais.buscarIcones('');

      expect(todos.length, CategoriaVisuais.catalogo.length);
      expect(
        todos.take(CategoriaVisuais.iconesSugeridos.length),
        CategoriaVisuais.iconesSugeridos,
      );
    });

    test('casa pelos termos em português', () {
      expect(CategoriaVisuais.buscarIcones('alimentacao'), contains('restaurant'));
      expect(CategoriaVisuais.buscarIcones('salario'), contains('payments'));
      expect(CategoriaVisuais.buscarIcones('imposto'), contains('receipt_long'));
      expect(CategoriaVisuais.buscarIcones('investimento'), contains('trending_up'));
    });

    test('ignora acento e caixa — ninguém digita acento na busca', () {
      expect(CategoriaVisuais.buscarIcones('ALIMENTAÇÃO'), contains('restaurant'));
      expect(CategoriaVisuais.buscarIcones('combustível'), contains('local_gas_station'));
    });

    test('termo sem correspondência devolve lista vazia', () {
      expect(CategoriaVisuais.buscarIcones('zzzznada'), isEmpty);
    });
  });
}
