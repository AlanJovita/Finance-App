import 'package:flutter/material.dart';

import '../../utils/app_tokens.dart';

/// Uma entrada de legenda: a marca da série e o rótulo dela.
///
/// Vive fora dos gráficos porque legenda é o canal de identidade de todos eles,
/// e três arquivos com a sua própria versão da mesma linha acabam com marcas de
/// tamanhos diferentes na mesma tela.
///
/// **A tinta do rótulo é de texto, nunca a da série.** Um matiz claro de série
/// é ilegível como texto sobre a superfície do card; a identidade vem da marca
/// ao lado, não da cor da letra.
class LegendaChart extends StatelessWidget {
  final String rotulo;

  /// Cor da marca — o quadradinho ou o traço.
  final Color cor;

  /// Traço tracejado em vez de quadrado: é o que distingue uma linha de
  /// referência (média, previsto) de uma série preenchida.
  final bool tracejada;

  /// Texto à direita do rótulo, na tinta secundária — o valor da série, quando
  /// a legenda também é a tabela do gráfico.
  final String? valor;

  const LegendaChart({
    super.key,
    required this.rotulo,
    required this.cor,
    this.tracejada = false,
    this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _marca(),
        const SizedBox(width: AppSpacing.sm),
        Text(rotulo, style: theme.textTheme.labelMedium),
        if (valor != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            valor!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _marca() {
    if (tracejada) {
      return SizedBox(
        width: 20,
        height: 3,
        child: CustomPaint(painter: _TracoTracejado(cor)),
      );
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _TracoTracejado extends CustomPainter {
  final Color cor;

  const _TracoTracejado(this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..color = cor
          ..strokeWidth = 2;
    const traco = 4.0;
    const vao = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + traco).clamp(0, size.width), size.height / 2),
        p,
      );
      x += traco + vao;
    }
  }

  @override
  bool shouldRepaint(_TracoTracejado old) => old.cor != cor;
}
