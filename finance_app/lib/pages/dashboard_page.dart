import 'package:finance_app/models/boleto.dart';
import 'package:finance_app/models/caixa.dart';
import 'package:finance_app/models/relatorio_mensal.dart';
import 'package:finance_app/models/relatorio_semanal.dart';
import 'package:finance_app/pages/caixa_page.dart';
import 'package:finance_app/services/api_service.dart';
import 'package:finance_app/services/global_state.dart';
import 'package:finance_app/utils/currency_formatter.dart';
import 'package:finance_app/widgets/boletos_widget.dart';
import 'package:finance_app/widgets/charts/monthly_charts_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_widgets.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/responsive_utils.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Caixa? _caixa;
  RelatorioSemanal? _relatorioSemanal;
  List<RelatorioMensal> _relatoriosMensais = [];
  List<Boleto> _boletos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      final caixa = await apiService.getCaixa();
      final relatoriosSemana = await apiService.getRelatorioSemanal();
      final relatoriosMensais = await apiService.getRelatorioMensal(
        DateTime.now().year,
      );

      // Busca o relatório do dia da semana atual
      final diaSemana = DateTime.now().weekday; // 1 = Segunda, 7 = Domingo
      RelatorioSemanal? relatorioSemanal;

      if (relatoriosSemana.isNotEmpty) {
        relatorioSemanal = relatoriosSemana.firstWhere(
          (r) => r.diaSemana == diaSemana,
          orElse: () => relatoriosSemana.first,
        );
      }

      // Busca boletos
      List<Boleto> boletos = [];
      try {
        // Tenta obter o id_cliente do GlobalState
        final idCliente = GlobalState().firstIdLoja;
        if (idCliente != 0) {
          boletos = await apiService.checkBoletos(idCliente);
        }
      } catch (e) {
        // Se falhar ao buscar boletos, apenas ignora e continua
        debugPrint('Erro ao buscar boletos: $e');
      }

      setState(() {
        _caixa = caixa;
        _relatorioSemanal = relatorioSemanal;
        _relatoriosMensais = relatoriosMensais;
        _boletos = boletos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(_caixa?.nomeLoja ?? 'Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Alternar tema',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
            tooltip: 'Sair',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body:
          _isLoading
              ? ShimmerWidgets.dashboardFullShimmer(context)
              : _error != null
              ? _buildErro()
              : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: context.responsivePadding(),
                  child: Column(
                    children: [
                      _buildMainCard(context),
                      SizedBox(height: context.responsiveSpacing()),
                      BoletosWidget(boletos: _boletos),
                      if (_boletos.isNotEmpty)
                        SizedBox(height: context.responsiveSpacing()),
                      _buildActionCardsRow(context),
                      SizedBox(height: context.responsiveSpacing()),
                      MonthlyChartsWidget(relatorios: _relatoriosMensais),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.appColors.error),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Erro ao carregar dados:\n$_error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  /// O relevo neumórfico do dashboard: uma sombra escura de um lado e uma luz
  /// do outro. Fica num helper porque se repete em três lugares.
  List<BoxShadow> _relevo(ThemeData theme, {double distancia = 6}) {
    final isDark = theme.brightness == Brightness.dark;
    return [
      BoxShadow(
        color:
            isDark
                ? Colors.black.withValues(alpha: 0.6)
                : Colors.grey.shade400,
        offset: Offset(distancia, distancia),
        blurRadius: 12,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        offset: Offset(-distancia, -distancia),
        blurRadius: 12,
        spreadRadius: 1,
      ),
    ];
  }

  Widget _buildMainCard(BuildContext context) {
    final caixa = _caixa;
    final theme = Theme.of(context);

    if (caixa == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Nenhum caixa disponível'),
        ),
      );
    }

    final dataFechamento = caixa.dataFechamento ?? DateTime.now();
    final statusAberto = caixa.statusCaixa == 0;
    final saldo = caixa.saldo ?? 0.0;
    final pedidosConfirmados = caixa.totalPedidoConfirmado ?? 0;
    final pedidosEstornados = caixa.totalPedidoEstornado ?? 0;

    // Dados do relatório semanal para comparação
    final relatorio = _relatorioSemanal;
    final mediaSaldo = relatorio?.mediaSaldo ?? 0.0;
    final recordSaldo = relatorio?.recordSaldo ?? 0.0;
    final mediaPedidos = relatorio?.mediaPedidosConfirmados ?? 0.0;
    final recordPedidos = relatorio?.recordPedidosConfirmados ?? 0;

    return ClipRect(
      child: Card(
        elevation: AppElevation.overlay,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.none,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dataFechamento.day.toString().padLeft(2, '0')}/${dataFechamento.month.toString().padLeft(2, '0')}',
                            style: theme.textTheme.headlineMedium,
                          ),
                          Text(
                            _getDiaSemana(dataFechamento.weekday),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      _buildBotaoDetalhes(caixa),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          'Saldo',
                          CurrencyFormatter.format(saldo),
                          mediaSaldo,
                          recordSaldo,
                          saldo,
                          null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          'Pedidos',
                          pedidosConfirmados.toString(),
                          mediaPedidos,
                          recordPedidos.toDouble(),
                          pedidosConfirmados.toDouble(),
                          pedidosEstornados,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildFaixaStatus(statusAberto),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoDetalhes(Caixa caixa) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CaixaPage(caixa: caixa)),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: _relevo(theme, distancia: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                color: theme.colorScheme.onSurface,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Detalhes', style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaixaStatus(bool statusAberto) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final cor = statusAberto ? cores.success : cores.error;

    return Positioned(
      top: 0,
      right: -40,
      child: Transform.rotate(
        angle: 0.785398, // 45 graus
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl - AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.9 : 0.5,
                ),
                blurRadius: 12,
                offset: const Offset(4, 4),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: cor.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.2 : 0.5,
                ),
                blurRadius: 12,
                offset: const Offset(-2, -2),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  statusAberto ? Icons.lock_open : Icons.lock,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    statusAberto ? 'Aberto' : 'Fechado',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    double media,
    double record,
    double currentValue,
    int? estornados,
  ) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    // Calcula percentuais
    final percentMedia =
        media > 0 ? ((currentValue - media) / media * 100) : 0.0;
    final percentRecord =
        record > 0 ? ((currentValue - record) / record * 100) : 0.0;

    final isBeatRecord = currentValue >= record && record > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
            isBeatRecord
                ? Border.all(
                  color: cores.warning.withValues(alpha: 0.5),
                  width: 2,
                )
                : null,
        boxShadow: _relevo(theme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isBeatRecord)
                Icon(Icons.emoji_events, color: cores.warning, size: 24),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: theme.textTheme.titleLarge),
              if (estornados != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, color: cores.warning, size: 14),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$estornados',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cores.warning,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          _buildComparacao(
            percentMedia,
            isMedia: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildComparacao(percentRecord, isMedia: false),
        ],
      ),
    );
  }

  Widget _buildComparacao(double percent, {required bool isMedia}) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final positivo = percent >= 0;
    final cor = positivo ? cores.success : cores.error;
    final referencia = isMedia ? 'média' : 'record';
    final preposicao = isMedia ? (positivo ? 'acima da' : 'abaixo da')
                               : (positivo ? 'acima do' : 'abaixo do');

    return Row(
      children: [
        Icon(
          positivo ? Icons.arrow_upward : Icons.arrow_downward,
          color: cor,
          size: 16,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '${CurrencyFormatter.formatSimple(percent.abs(), decimals: 0)}% $preposicao $referencia',
            style: theme.textTheme.labelSmall?.copyWith(color: cor),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCardsRow(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            Icons.view_list,
            '/caixas',
            'Caixas',
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildActionCard(
            context,
            Icons.arrow_upward,
            '/receitas',
            'Receitas',
            cores.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildActionCard(
            context,
            Icons.arrow_downward,
            '/despesas',
            'Despesas',
            cores.error,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String route,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: AppElevation.cardRaised,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 80,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDiaSemana(int weekday) {
    const dias = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    return dias[weekday - 1];
  }
}
