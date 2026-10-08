import 'package:flutter/material.dart';

import '../utils/bancos.dart';

/// Marca visual de uma conta bancária: o logo da instituição quando existe, e a
/// cor da marca com as iniciais do nome da conta quando não.
///
/// O fallback não é um acidente a evitar — é o caminho normal em três casos: a
/// conta sem instituição escolhida, a entrada que não é banco (dinheiro em
/// espécie, cofre) e o PNG que ainda não entrou no repositório. Por isso o
/// `errorBuilder`: um asset faltando não pode virar o retângulo cinza de erro do
/// Flutter no meio da lista de contas.
class LogoBanco extends StatelessWidget {
  /// Chave do catálogo gravada em `finance_conta.imagem` (código COMPE).
  final String? chave;

  /// Nome que o lojista deu à conta — origem das iniciais do fallback.
  final String nomeConta;

  final double diametro;

  const LogoBanco({
    super.key,
    required this.chave,
    required this.nomeConta,
    this.diametro = 44,
  });

  @override
  Widget build(BuildContext context) {
    final asset = Bancos.asset(chave);

    return Container(
      width: diametro,
      height: diametro,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child:
          asset == null
              ? _marca(context)
              : Image.asset(
                asset,
                fit: BoxFit.cover,
                // Carregar em escala menor que o arquivo evita decodificar um PNG
                // grande por item de lista. `diametro` é lógico; o fator cobre
                // telas 3x sem serrilhar.
                cacheWidth: (diametro * 3).round(),
                errorBuilder: (context, error, stack) => _marca(context),
              ),
    );
  }

  /// Cor da marca com as iniciais, ou o ícone da entrada quando ela não é banco.
  Widget _marca(BuildContext context) {
    final cor = Bancos.cor(chave);
    final sobre = Bancos.corDoTexto(cor);
    final item = Bancos.de(chave);

    // Carteira e cofre têm ícone próprio e nome curto; iniciais ali diriam menos
    // que o desenho de uma nota ou de um cofre.
    final usaIcone = item != null && !item.temLogo;

    return Container(
      alignment: Alignment.center,
      color: cor,
      child:
          usaIcone
              ? Icon(item.icone, color: sobre, size: diametro * 0.5)
              : Text(
                Bancos.iniciais(nomeConta),
                style: TextStyle(
                  color: sobre,
                  fontWeight: FontWeight.bold,
                  fontSize: diametro * 0.36,
                  height: 1,
                ),
              ),
    );
  }
}
