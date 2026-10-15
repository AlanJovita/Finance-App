import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Distribui cards de alturas diferentes em [colunas], cada um caindo na coluna
/// **mais curta** no momento em que entra.
///
/// Por que não um `GridView` nem uma `Row` de `Column`s:
///
/// - `GridView` dá a todo mundo a mesma altura, e o Resumo tem card de 90px
///   (atalhos) ao lado de card de 600px (gráfico com lista). A grade uniforme
///   obriga a altura do maior em toda a linha — o buraco que este arranjo
///   existe para não ter.
/// - `Row` de `Column`s fixas exige decidir **antes** quem vai em qual coluna,
///   e a altura de cada card depende de dados da loja (quantos boletos, quantos
///   lançamentos, se há gráfico). Qualquer divisão escrita à mão fica
///   desequilibrada para metade das lojas.
///
/// Daí o layout próprio: ele mede cada filho com a largura da coluna já
/// definida, e só então escolhe onde pôr. É a varredura gulosa clássica de
/// masonry — uma passada, sem reflow.
///
/// **A ordem da lista ainda manda no essencial.** Com todas as colunas vazias o
/// empate é resolvido pela primeira, então os [colunas] primeiros cards são
/// sempre os topos das colunas, na ordem recebida. O que fica por altura é só o
/// resto.
class GradeCartoes extends MultiChildRenderObjectWidget {
  const GradeCartoes({
    super.key,
    required this.colunas,
    required this.espaco,
    required List<Widget> cartoes,
  }) : assert(colunas > 0),
       super(children: cartoes);

  final int colunas;

  /// Respiro entre cards, nas duas direções.
  final double espaco;

  @override
  RenderGradeCartoes createRenderObject(BuildContext context) =>
      RenderGradeCartoes(colunas: colunas, espaco: espaco);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGradeCartoes renderObject,
  ) {
    renderObject
      ..colunas = colunas
      ..espaco = espaco;
  }
}

class _DadosCartao extends ContainerBoxParentData<RenderBox> {}

class RenderGradeCartoes extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DadosCartao>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DadosCartao> {
  RenderGradeCartoes({required int colunas, required double espaco})
    : _colunas = colunas,
      _espaco = espaco;

  int _colunas;
  int get colunas => _colunas;
  set colunas(int valor) {
    if (_colunas == valor) return;
    _colunas = valor;
    markNeedsLayout();
  }

  double _espaco;
  double get espaco => _espaco;
  set espaco(double valor) {
    if (_espaco == valor) return;
    _espaco = valor;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _DadosCartao) child.parentData = _DadosCartao();
  }

  double _larguraColuna(double disponivel) =>
      (disponivel - espaco * (colunas - 1)) / colunas;

  /// Índice da coluna mais curta. Comparação **estrita**, para que o empate
  /// (todas em zero, no começo) caia sempre na coluna mais à esquerda — é o que
  /// preserva a ordem recebida nos primeiros cards.
  int _maisCurta(List<double> alturas) {
    var alvo = 0;
    for (var i = 1; i < alturas.length; i++) {
      if (alturas[i] < alturas[alvo]) alvo = i;
    }
    return alvo;
  }

  @override
  void performLayout() {
    assert(
      constraints.hasBoundedWidth,
      'GradeCartoes precisa de largura limitada: ela divide o que recebe '
      'entre as colunas.',
    );

    final disponivel = constraints.maxWidth;
    final largura = _larguraColuna(disponivel);
    final alturas = List<double>.filled(colunas, 0);

    var child = firstChild;
    while (child != null) {
      final dados = child.parentData! as _DadosCartao;

      // Largura travada, altura livre: é o card que diz quanto ocupa, e é esse
      // número que decide a coluna do próximo.
      child.layout(
        BoxConstraints.tightFor(width: largura),
        parentUsesSize: true,
      );

      final alvo = _maisCurta(alturas);
      dados.offset = Offset(alvo * (largura + espaco), alturas[alvo]);
      alturas[alvo] += child.size.height + espaco;

      child = dados.nextSibling;
    }

    // `- espaco` porque o respiro é somado depois de cada card, inclusive do
    // último de cada coluna; sem isso a grade reservaria um rodapé fantasma.
    final altura = math.max(0.0, alturas.reduce(math.max) - espaco);
    size = constraints.constrain(Size(disponivel, altura));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return constraints.smallest;

    final largura = _larguraColuna(constraints.maxWidth);
    final alturas = List<double>.filled(colunas, 0);

    var child = firstChild;
    while (child != null) {
      final tamanho = child.getDryLayout(
        BoxConstraints.tightFor(width: largura),
      );
      final alvo = _maisCurta(alturas);
      alturas[alvo] += tamanho.height + espaco;
      child = (child.parentData! as _DadosCartao).nextSibling;
    }

    final altura = math.max(0.0, alturas.reduce(math.max) - espaco);
    return constraints.constrain(Size(constraints.maxWidth, altura));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
