import 'package:flutter/material.dart';

import '../utils/bandeiras.dart';

/// Marca visual de uma bandeira de cartão: o logo quando existe, e a cor da marca
/// com o ícone de cartão quando não.
///
/// Gêmeo do [LogoBanco], com uma diferença de forma que não é estética: aqui
/// **não há recorte circular**. A maioria das bandeiras tem símbolo largo — o
/// retângulo da Visa, os dois círculos do Mastercard, o logotipo da Amex — e um
/// círculo cortaria as pontas justamente da parte que identifica a marca. Daí o
/// retângulo arredondado com `BoxFit.contain`.
///
/// O fallback é o caminho normal em dois casos: o cartão sem bandeira escolhida e
/// o PNG que ainda não entrou no repositório. Por isso o `errorBuilder`: um asset
/// faltando não pode virar o retângulo cinza de erro do Flutter no meio da lista
/// de cartões.
class LogoBandeira extends StatelessWidget {
  /// Chave do catálogo gravada em `finance_cartao.bandeira`.
  final String? chave;

  /// Largura do selo. A altura sai de [proporcao] — bandeira é um retângulo
  /// deitado, não um quadrado.
  final double largura;

  /// Altura em relação à largura. 0.63 é a proporção aproximada de um cartão,
  /// que é onde o olho está acostumado a ver estes símbolos.
  final double proporcao;

  const LogoBandeira({
    super.key,
    required this.chave,
    this.largura = 40,
    this.proporcao = 0.63,
  });

  @override
  Widget build(BuildContext context) {
    final asset = Bandeiras.asset(chave);
    final altura = largura * proporcao;

    return Container(
      width: largura,
      height: altura,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(largura * 0.12),
        // O fundo da marca fica atrás do PNG também: os logos têm fundo
        // transparente, e sobre o card claro a Visa azul-marinho desaparece. É o
        // mesmo papel da cor no `LogoBanco`, que o recorte circular preenche.
        color: Bandeiras.cor(chave),
      ),
      child:
          asset == null
              ? _marca(context, altura)
              : Padding(
                padding: EdgeInsets.all(largura * 0.1),
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  // Carregar em escala menor que o arquivo evita decodificar um
                  // PNG grande por item de lista. `largura` é lógica; o fator
                  // cobre telas 3x sem serrilhar.
                  cacheWidth: (largura * 3).round(),
                  errorBuilder: (context, error, stack) => _marca(context, altura),
                ),
              ),
    );
  }

  Widget _marca(BuildContext context, double altura) {
    final sobre = Bandeiras.corDoTexto(Bandeiras.cor(chave));

    return Center(
      child: Icon(Bandeiras.iconeGenerico, color: sobre, size: altura * 0.62),
    );
  }
}
