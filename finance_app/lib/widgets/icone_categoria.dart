import 'package:flutter/material.dart';

import '../utils/categoria_visuais.dart';

/// Marca visual de um lançamento: o círculo da categoria e, quando existe, o da
/// subcategoria à direita com metade do diâmetro.
///
/// A filha herda a cor do pai a [CategoriaVisuais.opacidadeSubcategoria] — a
/// mesma regra do seletor do formulário, para o par ler como variação e não
/// como duas categorias soltas.
class IconeCategoria extends StatelessWidget {
  final String? iconeCategoria;
  final Color corCategoria;

  /// Nulo quando o lançamento não tem subcategoria — aí só o círculo maior é
  /// desenhado e o widget fica mais estreito.
  final String? iconeSubcategoria;
  final bool temSubcategoria;

  /// Selo sobreposto ao canto inferior direito do círculo da categoria.
  ///
  /// Quando vem preenchido, **substitui** o círculo da subcategoria. Na lista de
  /// receitas e despesas o que precisa ser lido de relance em cada linha é a
  /// situação (confirmado, atrasado, pendente), e os dois selos na mesma marca
  /// virariam enfeite: a subcategoria continua escrita na trilha ao lado.
  ///
  /// Sobreposto, e não ao lado, porque a largura economizada aqui é a que
  /// sobra para a trilha e para a conta na linha de baixo — o aperto horizontal
  /// é o detalhe mais frágil do card.
  final Widget? badge;

  final double diametro;

  const IconeCategoria({
    super.key,
    required this.iconeCategoria,
    required this.corCategoria,
    this.iconeSubcategoria,
    this.temSubcategoria = false,
    this.badge,
    this.diametro = 36,
  });

  @override
  Widget build(BuildContext context) {
    final corFilha = corCategoria.withValues(
      alpha: CategoriaVisuais.opacidadeSubcategoria,
    );

    final circuloCategoria = _circulo(
      context,
      icone: CategoriaVisuais.icone(iconeCategoria),
      cor: corCategoria,
      tamanho: diametro,
    );

    if (badge != null) {
      // `clipBehavior: none` deixa o selo passar da caixa do círculo: ele fica
      // mordendo o canto, em vez de ser recortado por ele.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          circuloCategoria,
          Positioned(right: -2, bottom: -2, child: badge!),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        circuloCategoria,
        if (temSubcategoria) ...[
          const SizedBox(width: 2),
          _circulo(
            context,
            icone: CategoriaVisuais.icone(iconeSubcategoria),
            cor: corFilha,
            tamanho: diametro / 2,
          ),
        ],
      ],
    );
  }

  Widget _circulo(
    BuildContext context, {
    required IconData icone,
    required Color cor,
    required double tamanho,
  }) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cor.withValues(alpha: 0.18),
        // Sem a borda os dois círculos encostam e, com cores próximas, leem
        // como uma mancha só.
        border: Border.all(color: cor.withValues(alpha: 0.45)),
      ),
      // O glifo ocupa metade do círculo nos dois tamanhos, então o par mantém
      // a mesma densidade visual.
      child: Icon(icone, color: cor, size: tamanho * 0.5),
    );
  }
}
