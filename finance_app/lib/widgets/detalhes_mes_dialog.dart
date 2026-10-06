import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/fluxo_caixa.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import '../utils/situacao_fluxo.dart';

/// Margem que o diálogo guarda contra a borda da tela.
const double _inset = AppSpacing.lg;

/// Quantidade e valor de um recorte — a unidade de tudo que este modal mostra.
class _Agregado {
  int quantidade = 0;
  double valor = 0;

  void somar(FluxoCaixa fluxo) {
    quantidade++;
    valor += fluxo.valor ?? 0;
  }
}

/// Panorama do mês em três blocos: resumo, situação e recorrências.
///
/// Trabalha sobre a lista que a tela já tem em memória — nenhuma requisição
/// nova. Por isso ele reflete exatamente o que está listado, filtros inclusos,
/// e avisa quando há filtro ativo para o número não parecer o do mês inteiro.
class DetalhesMesDialog extends StatefulWidget {
  final String mesReferencia;
  final List<FluxoCaixa> itens;

  /// Define a cor de destaque: receita puxa `success`, despesa puxa `error`.
  final bool ehReceita;

  final bool filtroAtivo;

  const DetalhesMesDialog({
    super.key,
    required this.mesReferencia,
    required this.itens,
    required this.ehReceita,
    this.filtroAtivo = false,
  });

  @override
  State<DetalhesMesDialog> createState() => _DetalhesMesDialogState();
}

class _DetalhesMesDialogState extends State<DetalhesMesDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada;

  late final Map<GrupoSituacao, _Agregado> _situacoes;
  late final Map<TipoRecorrencia, _Agregado> _recorrencias;
  late final _Agregado _total;

  @override
  void initState() {
    super.initState();
    _agregar();

    // Uma passada só, 520ms, e para. Nada fica animando enquanto o modal
    // estiver aberto — é o que mantém o custo perto de zero depois da entrada.
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  void _agregar() {
    _situacoes = {for (final g in GrupoSituacao.values) g: _Agregado()};
    _recorrencias = {for (final t in TipoRecorrencia.values) t: _Agregado()};
    _total = _Agregado();

    final hoje = DateTime.now();
    for (final fluxo in widget.itens) {
      _situacoes[SituacaoFluxo.de(fluxo, hoje: hoje).grupo]!.somar(fluxo);
      _recorrencias[TipoRecorrencia.de(fluxo)]!.somar(fluxo);
      _total.somar(fluxo);
    }
  }

  /// Fatias e barras são proporcionais ao valor. Num mês em que tudo foi
  /// lançado com valor zero isso daria um gráfico vazio com registros na tela,
  /// então ali a proporção passa a ser a contagem.
  bool get _proporcionalAoValor => _total.valor > 0;

  double _peso(_Agregado a) =>
      _proporcionalAoValor ? a.valor : a.quantidade.toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final cor = widget.ehReceita ? cores.success : cores.error;

    // Desconta o que o diálogo gasta antes de chegar ao conteúdo: a margem
    // contra a borda da tela (dos dois lados) e o próprio `contentPadding`.
    // Medir por fração da tela, sem isso, estoura no celular.
    final largura = (MediaQuery.sizeOf(context).width -
            _inset * 2 -
            AppSpacing.xl * 2)
        .clamp(0.0, 460.0);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: AppSpacing.xl,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      title: Row(
        children: [
          Icon(Icons.insights, color: cor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.ehReceita ? 'Detalhes das receitas' : 'Detalhes das despesas',
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      content: SizedBox(
        width: largura,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.filtroAtivo) _buildAvisoFiltro(theme, cores),
              _animado(0.0, _buildResumo(theme, cor, largura < 380)),
              const SizedBox(height: AppSpacing.lg),
              _animado(0.15, _buildSituacao(theme, cores, largura < 380)),
              const SizedBox(height: AppSpacing.lg),
              _animado(0.3, _buildRecorrencias(theme, cores)),
            ],
          ),
        ),
      ),
    );
  }

  /// Fade + deslize curto, escalonado por seção para o conteúdo "assentar" de
  /// cima para baixo em vez de aparecer de uma vez.
  Widget _animado(double inicio, Widget filho) {
    final curva = CurvedAnimation(
      parent: _entrada,
      curve: Interval(inicio, (inicio + 0.7).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curva),
        child: filho,
      ),
    );
  }

  Widget _buildAvisoFiltro(ThemeData theme, AppColors cores) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 14, color: cores.info),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Considerando apenas as contas filtradas.',
              style: theme.textTheme.bodySmall?.copyWith(color: cores.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecao(ThemeData theme, String titulo, Widget filho) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        filho,
      ],
    );
  }

  Widget _buildResumo(ThemeData theme, Color cor, bool estreito) {
    final mes = _tile(theme, 'Mês de referência', widget.mesReferencia);
    final registros = _tile(theme, 'Registros', '${_total.quantidade}');
    final total = _tile(
      theme,
      'Total',
      CurrencyFormatter.format(_total.valor),
      cor: cor,
      contar: _total.valor,
    );

    return _buildSecao(
      theme,
      'Resumo',
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        // Três colunas num celular deixam os rótulos encostados um no outro e
        // cortam o total; o mês sobe para a própria linha e os dois números
        // dividem a de baixo.
        child:
            estreito
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    mes,
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: registros),
                        Expanded(flex: 2, child: total),
                      ],
                    ),
                  ],
                )
                : Row(
                  children: [
                    Expanded(flex: 3, child: mes),
                    Expanded(flex: 2, child: registros),
                    Expanded(flex: 3, child: total),
                  ],
                ),
      ),
    );
  }

  Widget _tile(
    ThemeData theme,
    String rotulo,
    String valor, {
    Color? cor,
    double? contar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rotulo,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        if (contar != null)
          // O total sobe de zero até o valor: é o número que o olho procura
          // primeiro, e o movimento o entrega como tal.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: contar),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder:
                (context, v, _) => Text(
                  CurrencyFormatter.format(v),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          )
        else
          Text(
            valor,
            style: theme.textTheme.titleSmall?.copyWith(
              color: cor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildSituacao(ThemeData theme, AppColors cores, bool estreito) {
    final comPeso = GrupoSituacao.values
        .where((g) => _peso(_situacoes[g]!) > 0)
        .toList();

    final donut = SizedBox(
            width: 108,
            height: 108,
            child:
                comPeso.isEmpty
                    ? Center(
                      child: Text(
                        'Sem dados',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    // ScaleTransition aplica só uma transformação por frame; o
                    // PieChartData não é remontado durante a entrada.
                    : ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _entrada,
                        curve: const Interval(0.15, 0.85,
                            curve: Curves.easeOutBack),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                              startDegreeOffset: -90,
                              pieTouchData: PieTouchData(enabled: false),
                              sections: [
                                for (final g in comPeso)
                                  PieChartSectionData(
                                    value: _peso(_situacoes[g]!),
                                    color: g.cor(cores),
                                    radius: 22,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_total.quantidade}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _total.quantidade == 1 ? 'conta' : 'contas',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
          );

    final legenda = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in GrupoSituacao.values)
          _linhaLegenda(
            theme,
            cor: g.cor(cores),
            icone: g.icone,
            rotulo: g.rotulo,
            agregado: _situacoes[g]!,
          ),
      ],
    );

    return _buildSecao(
      theme,
      'Situação',
      // Ao lado do donut a legenda fica com metade da largura, e "Próximas do
      // vencimento" não cabe num celular. Embaixo ela usa a linha inteira.
      estreito
          ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: donut),
              const SizedBox(height: AppSpacing.md),
              legenda,
            ],
          )
          : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: legenda),
            ],
          ),
    );
  }

  Widget _linhaLegenda(
    ThemeData theme, {
    required Color cor,
    required IconData icone,
    required String rotulo,
    required _Agregado agregado,
  }) {
    final apagado = agregado.quantidade == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icone,
            size: 13,
            color: apagado ? theme.colorScheme.onSurfaceVariant : cor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              rotulo,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    apagado
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${agregado.quantidade}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            CurrencyFormatter.format(agregado.valor),
            style: theme.textTheme.labelMedium?.copyWith(
              color: apagado ? theme.colorScheme.onSurfaceVariant : cor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecorrencias(ThemeData theme, AppColors cores) {
    final maior = TipoRecorrencia.values
        .map((t) => _peso(_recorrencias[t]!))
        .fold<double>(0, (a, b) => a > b ? a : b);

    return _buildSecao(
      theme,
      'Recorrências',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in TipoRecorrencia.values)
            _barra(
              theme,
              tipo: t,
              cor: t.cor(cores),
              agregado: _recorrencias[t]!,
              // Proporção relativa ao maior grupo, não ao total: com um grupo
              // dominante as outras barras viriam como fios invisíveis.
              fracao: maior > 0 ? _peso(_recorrencias[t]!) / maior : 0,
            ),
        ],
      ),
    );
  }

  Widget _barra(
    ThemeData theme, {
    required TipoRecorrencia tipo,
    required Color cor,
    required _Agregado agregado,
    required double fracao,
  }) {
    final apagado = agregado.quantidade == 0;
    final fracaoFinal = apagado ? 0.0 : (fracao < 0.03 ? 0.03 : fracao);
    final curva = CurvedAnimation(
      parent: _entrada,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                tipo.icone,
                size: 13,
                color: apagado ? theme.colorScheme.onSurfaceVariant : cor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  tipo.rotulo,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Text(
                '${agregado.quantidade}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                CurrencyFormatter.format(agregado.valor),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: apagado ? theme.colorScheme.onSurfaceVariant : cor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              height: 6,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              child: AnimatedBuilder(
                animation: curva,
                builder:
                    (context, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      // Piso de 3% para um grupo que tem lançamentos não sumir
                      // na barra quando outro domina o valor — fica visível que
                      // existe, sem desmentir a proporção.
                      widthFactor: (fracaoFinal * curva.value).clamp(0.0, 1.0),
                      child: Container(color: cor),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
