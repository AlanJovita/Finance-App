import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/resumo_painel.dart';
import '../../utils/app_colors_extension.dart';
import '../../utils/app_tokens.dart';
import '../../utils/currency_formatter.dart';
import 'legenda_chart.dart';

/// O mês acumulado dia a dia: o que já foi realizado contra o que foi previsto.
///
/// **Forma:** acumulado, e não barra por dia. A pergunta do lojista é "quanto já
/// entrou e quanto vou fechar o mês", que é um total correndo — a barra diária
/// responde "em que dia vence o quê", outra pergunta, e em celular 31 colunas
/// ficam com 8px cada. O acumulado lê igual em qualquer largura.
///
/// **Duas séries, e o par é de propósito:** a distância vertical entre as
/// linhas é literalmente o que falta acontecer no mês. Cada linha termina num
/// número que o card ao lado também mostra — o fim do previsto é o
/// `receitas_previsto`\`despesas_previsto` do resumo, e o fim do realizado é o
/// `*_realizado`. Se as duas pontas não fechassem com o card, uma das duas
/// estaria somando outra coisa.
///
/// **O realizado para em "hoje".** Prolongá-lo reto até o dia 31 desenharia uma
/// linha chapada que afirma "nada mais entrou", quando o certo é "ainda não
/// aconteceu". Num mês passado não há corte: o mês inteiro já aconteceu.
///
/// **Cores:** um matiz de natureza (entrada é `success`, saída é `error` — a
/// mesma convenção do resto do app) para o realizado, e a tinta de texto
/// tracejada para o previsto, igual à linha de média do [MonthlyChartsWidget]:
/// previsto é base de comparação, e pintá-lo de série o colocaria em pé de
/// igualdade com o que de fato aconteceu.
class FluxoAcumuladoChart extends StatefulWidget {
  /// Só os dias com movimento; os vazios são completados aqui.
  final List<MovimentoDia> diario;

  /// Primeiro e último dia do mês em foco, como o servidor os resolveu.
  final DateTime inicio;
  final DateTime fim;

  /// Receita puxa a cor de entrada; despesa, a de saída.
  final bool ehReceita;

  /// Injetável para o teste fixar o corte do realizado — sem isso o golden
  /// mudaria de desenho a cada dia.
  final DateTime? hoje;

  const FluxoAcumuladoChart({
    super.key,
    required this.diario,
    required this.inicio,
    required this.fim,
    required this.ehReceita,
    this.hoje,
  });

  @override
  State<FluxoAcumuladoChart> createState() => _FluxoAcumuladoChartState();
}

class _FluxoAcumuladoChartState extends State<FluxoAcumuladoChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada;

  /// Acumulado por dia, índice 1..[_ultimoDia] — o 0 existe só para o índice
  /// bater com o número do dia.
  late final List<double> _previsto;
  late final List<double> _realizado;

  /// Último dia que o realizado desenha. Igual a [_ultimoDia] num mês que já
  /// acabou; 0 num mês que ainda não começou.
  late final int _corte;

  int get _ultimoDia => widget.fim.day;

  @override
  void initState() {
    super.initState();
    _acumular();

    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  void _acumular() {
    final porDia = List<double>.filled(_ultimoDia + 2, 0);
    final porDiaReal = List<double>.filled(_ultimoDia + 2, 0);

    for (final d in widget.diario) {
      // Um `dia` fora do mês só chegaria aqui por resposta corrompida; ignorar
      // é melhor que estourar o índice e derrubar o painel.
      if (d.dia < 1 || d.dia > _ultimoDia) continue;
      porDia[d.dia] += widget.ehReceita ? d.receitas : d.despesas;
      porDiaReal[d.dia] +=
          widget.ehReceita ? d.receitasRealizado : d.despesasRealizado;
    }

    _previsto = List<double>.filled(_ultimoDia + 1, 0);
    _realizado = List<double>.filled(_ultimoDia + 1, 0);

    for (var dia = 1; dia <= _ultimoDia; dia++) {
      _previsto[dia] = _previsto[dia - 1] + porDia[dia];
      _realizado[dia] = _realizado[dia - 1] + porDiaReal[dia];
    }

    _corte = _diaDeCorte();
  }

  /// Até onde o realizado é informação, e não afirmação sobre o futuro.
  int _diaDeCorte() {
    final agora = widget.hoje ?? DateTime.now();

    if (agora.year == widget.inicio.year &&
        agora.month == widget.inicio.month) {
      return agora.day.clamp(1, _ultimoDia);
    }

    // Mês passado já aconteceu inteiro; mês futuro não tem realizado nenhum.
    final passado =
        agora.isAfter(widget.fim) ||
        (agora.year == widget.fim.year && agora.month > widget.fim.month) ||
        agora.year > widget.fim.year;

    return passado ? _ultimoDia : 0;
  }

  double get _totalPrevisto => _previsto[_ultimoDia];
  double get _totalRealizado => _corte == 0 ? 0 : _realizado[_corte];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final cor = widget.ehReceita ? cores.success : cores.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // O valor vive no cabeçalho, não na ponta da linha: no celular um
        // rótulo colado na borda direita do traçado é cortado pelo card, e as
        // duas pontas juntas colidiriam sempre que o mês estivesse quase todo
        // realizado.
        Text(
          CurrencyFormatter.format(_totalRealizado),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'realizado de ${CurrencyFormatter.format(_totalPrevisto)} previstos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 180,
          child: AnimatedBuilder(
            animation: _entrada,
            builder: (context, _) => LineChart(_dados(theme, cor)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            LegendaChart(rotulo: 'Realizado', cor: cor),
            LegendaChart(
              rotulo: 'Previsto',
              cor: _tintaReferencia(theme),
              tracejada: true,
            ),
          ],
        ),
      ],
    );
  }

  LineChartData _dados(ThemeData theme, Color cor) {
    final progresso = _entrada.value;
    final topo = _topo();

    return LineChartData(
      minX: 1,
      maxX: _ultimoDia.toDouble(),
      minY: 0,
      maxY: topo,
      clipData: const FlClipData.all(),
      lineTouchData: _toque(theme),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: topo / 2,
        getDrawingHorizontalLine:
            (_) => FlLine(color: theme.dividerColor, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            // Intervalo de 1 com filtro no builder: `interval: 7` começaria no
            // minX e o último dia do mês nunca cairia na grade.
            interval: 1,
            getTitlesWidget: (value, meta) {
              final dia = value.round();
              if (!_rotulaDia(dia)) return const SizedBox.shrink();

              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: Text('$dia', style: theme.textTheme.bodySmall),
              );
            },
          ),
        ),
        // Três marcas: com o total impresso no cabeçalho, o eixo é escala, não
        // leitura de valor.
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 54,
            interval: topo / 2,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'R\$ ${CurrencyFormatter.compacto(value)}',
                    maxLines: 1,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        // O previsto vai primeiro para o realizado ficar desenhado por cima
        // dele onde os dois se encostam.
        LineChartBarData(
          spots: [
            for (var dia = 1; dia <= _ultimoDia; dia++)
              FlSpot(dia.toDouble(), _previsto[dia] * progresso),
          ],
          isCurved: false,
          barWidth: 2,
          color: _tintaReferencia(theme),
          dashArray: const [4, 4],
          dotData: const FlDotData(show: false),
        ),
        if (_corte > 0)
          LineChartBarData(
            spots: [
              for (var dia = 1; dia <= _corte; dia++)
                FlSpot(dia.toDouble(), _realizado[dia] * progresso),
            ],
            isCurved: false,
            barWidth: 2,
            color: cor,
            // Lavagem de 10%, não bloco saturado: a área é o que dá peso visual
            // ao realizado sem competir com a linha.
            belowBarData: BarAreaData(
              show: true,
              color: cor.withValues(alpha: 0.10),
            ),
            // Só a ponta ganha marcador — é onde o acumulado está agora. O anel
            // na cor da superfície é o que o mantém legível onde cruza a linha
            // do previsto.
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot.x == _corte.toDouble(),
              getDotPainter:
                  (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: cor,
                    strokeWidth: 2,
                    strokeColor: theme.cardColor,
                  ),
            ),
          ),
      ],
    );
  }

  /// Teto do eixo com 15% de folga, para a ponta da linha não encostar na borda.
  double _topo() {
    final maior =
        _totalPrevisto > _totalRealizado ? _totalPrevisto : _totalRealizado;
    // Mês sem lançamento nenhum: um teto de 0 faria o fl_chart dividir por zero
    // no intervalo da grade.
    return maior > 0 ? maior * 1.15 : 1;
  }

  /// Dias 1, 8, 15, 22 e o último. O vizinho do último sai de cena: com 29 e 30
  /// na mesma grade os dois rótulos se encostam.
  bool _rotulaDia(int dia) {
    if (dia == 1 || dia == _ultimoDia) return true;
    return dia % 7 == 1 && _ultimoDia - dia >= 3;
  }

  LineTouchData _toque(ThemeData theme) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
        // Uma linha por série tocada, com o dia no topo da primeira.
        getTooltipItems: (spots) {
          return [
            for (final (i, spot) in spots.indexed)
              LineTooltipItem(
                i == 0
                    ? 'Dia ${spot.x.round()}\n${_rotuloSerie(spot)}'
                    : _rotuloSerie(spot),
                TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: i == 0 ? FontWeight.bold : FontWeight.w500,
                ),
              ),
          ];
        },
      ),
    );
  }

  /// `barIndex` 0 é o previsto; 1, quando existe, é o realizado.
  String _rotuloSerie(LineBarSpot spot) {
    final nome = spot.barIndex == 0 ? 'Previsto' : 'Realizado';
    return '$nome: ${CurrencyFormatter.format(spot.y)}';
  }

  /// Tinta do previsto: texto secundário, não cor de série — ver a doc da
  /// classe.
  Color _tintaReferencia(ThemeData theme) =>
      theme.textTheme.bodySmall?.color ?? theme.hintColor;
}
