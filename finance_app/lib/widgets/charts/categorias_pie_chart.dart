import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/categoria.dart';
import '../../models/resumo_painel.dart';
import '../../utils/app_tokens.dart';
import '../../utils/categoria_visuais.dart';
import '../../utils/currency_formatter.dart';

/// Quanto do mês cada categoria responde, em anel, com a legenda servindo de
/// tabela.
///
/// **Forma:** parte-do-todo é a única pergunta que a pizza responde melhor que
/// uma barra, e é exatamente esta — "em que a minha despesa foi". O anel guarda
/// o total no centro porque o todo é a referência de toda fatia; sem ele o
/// leitor sabe as proporções e não sabe de quanto.
///
/// **No máximo [fatias] fatias, o resto vira "Outras".** Acima de meia dúzia as
/// fatias vizinhas ficam com poucos graus e deixam de ser compráveis — e com a
/// cor vinda do cadastro, duas fatias finas e de matiz parecido viram uma
/// mancha. A cauda agregada não é perda de informação: ela continua no total, e
/// o detalhe por categoria é a tela de Receitas/Despesas com o filtro.
///
/// **A cor é a da categoria, não uma paleta do gráfico.** Ela já identifica a
/// categoria no ícone de todo card e no seletor do formulário; uma paleta
/// própria aqui faria a fatia "Aluguel" ser roxa no painel e vermelha na lista.
/// O custo é que duas categorias podem ter sido cadastradas com a mesma cor —
/// por isso a identidade de cada fatia é a **legenda com nome e valor**, nunca
/// a cor sozinha, e as fatias são separadas por um vão na cor da superfície em
/// vez de um contorno.
class CategoriasPieChart extends StatefulWidget {
  /// Já vêm do servidor em ordem decrescente de valor.
  final List<TotalCategoria> grupos;

  /// Nome, cor e ícone de cada categoria, pelo id. O que não estiver aqui
  /// (categoria apagada noutra aba, ou `id_categoria = 0`) cai em
  /// "Sem categoria".
  final Map<int, Categoria> categorias;

  const CategoriasPieChart({
    super.key,
    required this.grupos,
    required this.categorias,
  });

  /// Quantas fatias nomeadas o anel desenha antes de agregar o resto.
  static const int fatias = 5;

  @override
  State<CategoriasPieChart> createState() => _CategoriasPieChartState();
}

class _CategoriasPieChartState extends State<CategoriasPieChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada;

  /// Fatia tocada, ou -1. Destacar só com o toque mantém o anel quieto em
  /// repouso.
  int _tocada = -1;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fatias = _fatias(context);

    if (fatias.isEmpty) {
      return Text(
        'Nenhum lançamento no mês',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final total = fatias.fold<double>(0, (s, f) => s + f.valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 168,
            height: 168,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _entrada,
                curve: const Interval(0.1, 1, curve: Curves.easeOutBack),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      // O vão é o separador — ver a doc da classe.
                      sectionsSpace: 2,
                      centerSpaceRadius: 48,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (evento, resposta) {
                          setState(() {
                            _tocada =
                                evento.isInterestedForInteractions
                                    ? resposta
                                            ?.touchedSection
                                            ?.touchedSectionIndex ??
                                        -1
                                    : -1;
                          });
                        },
                      ),
                      sections: [
                        for (final (i, f) in fatias.indexed)
                          PieChartSectionData(
                            value: f.valor,
                            color: f.cor,
                            // A fatia tocada cresce 4px; sem isso, num anel de
                            // seis fatias não há como saber qual delas o
                            // tooltip está descrevendo.
                            radius: _tocada == i ? 32 : 28,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.format(total),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'no mês',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // A legenda é também a tabela do gráfico: todo valor é legível sem
        // depender do toque.
        for (final (i, f) in fatias.indexed)
          _linha(theme, f, total, tocada: _tocada == i),
      ],
    );
  }

  /// [tocada] acende a linha da fatia que o dedo está sobre: sem isso, crescer
  /// a fatia no anel não diz *qual* categoria cresceu.
  Widget _linha(
    ThemeData theme,
    _Fatia f,
    double total, {
    required bool tocada,
  }) {
    final percentual = total > 0 ? f.valor / total * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tocada ? f.cor.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: f.cor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              f.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Tinta de texto, nunca a da fatia: cor de categoria clara é
              // ilegível como letra sobre o card.
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            CurrencyFormatter.format(f.valor),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 38,
            child: Text(
              '${percentual.round()}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// As fatias nomeadas mais a cauda agregada, descartando valor zero.
  ///
  /// Zero não é fatia: ela não teria ângulo nenhum e ainda ocuparia uma linha
  /// da legenda e uma cor.
  List<_Fatia> _fatias(BuildContext context) {
    final theme = Theme.of(context);

    final comValor = widget.grupos.where((g) => g.valor > 0).toList();
    if (comValor.isEmpty) return const [];

    final nomeadas =
        comValor
            .take(CategoriasPieChart.fatias)
            .map(
              (g) => _Fatia(
                rotulo: _rotulo(g),
                valor: g.valor,
                cor: _cor(g),
              ),
            )
            .toList();

    if (comValor.length <= CategoriasPieChart.fatias) return nomeadas;

    final resto = comValor.skip(CategoriasPieChart.fatias);

    return [
      ...nomeadas,
      _Fatia(
        rotulo: 'Outras (${resto.length})',
        valor: resto.fold<double>(0, (s, g) => s + g.valor),
        // Cinza de texto: a cauda não tem identidade própria, é o resto.
        cor: theme.colorScheme.onSurfaceVariant,
      ),
    ];
  }

  String _rotulo(TotalCategoria g) =>
      widget.categorias[g.idCategoria]?.descricao ?? 'Sem categoria';

  Color _cor(TotalCategoria g) =>
      CategoriaVisuais.cor(widget.categorias[g.idCategoria]?.cor);
}

/// Uma fatia já resolvida: rótulo, valor e cor. Existe para o anel e a legenda
/// lerem a mesma lista — montar as duas separadamente foi o que já deixou uma
/// fatia sem par na legenda noutra tela.
class _Fatia {
  final String rotulo;
  final double valor;
  final Color cor;

  const _Fatia({
    required this.rotulo,
    required this.valor,
    required this.cor,
  });
}
