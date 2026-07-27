import 'package:finance_app/pages/caixa_page.dart';
import 'package:finance_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import '../models/caixa.dart';
import '../services/api_service.dart';
import '../widgets/charts/caixas_chart_widget.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_widgets.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/responsive_utils.dart';

class ListaCaixasPage extends StatefulWidget {
  const ListaCaixasPage({super.key});

  @override
  State<ListaCaixasPage> createState() => _ListaCaixasPageState();
}

class _ListaCaixasPageState extends State<ListaCaixasPage>
    with SingleTickerProviderStateMixin {
  late Future<List<Caixa>> _caixasFuture;
  final ApiService _apiService = ApiService();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadCaixas();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadCaixas() {
    setState(() {
      _caixasFuture = _apiService.getCaixas();
    });
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Caixas')),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<Caixa>>(
        future: _caixasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SingleChildScrollView(
              padding: context.responsivePadding(),
              child: Column(
                children: [
                  ShimmerWidgets.chartShimmer(
                    context,
                    height: ResponsiveUtils.getChartHeight(context),
                  ),
                  SizedBox(height: context.responsiveSpacing()),
                  ShimmerWidgets.listCaixasShimmer(context),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum caixa encontrado.'));
          }

          final caixas = snapshot.data!;
          return SingleChildScrollView(
            padding: context.responsivePadding(),
            child: Column(
              children: [
                CaixasChartWidget(caixas: caixas),
                const SizedBox(height: AppSpacing.lg),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: caixas.length,
                  itemBuilder:
                      (context, index) =>
                          _buildCaixaAnimado(caixas[index], index, caixas.length),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaixaAnimado(Caixa caixa, int index, int total) {
    final inicio = (index / total) * 0.5;
    final fim = ((index + 1) / total) * 0.5 + 0.5;

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(inicio, fim, curve: Curves.easeOutCubic),
      ),
    );

    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(inicio, fim, curve: Curves.easeIn),
      ),
    );

    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: _buildCaixa(caixa)),
    );
  }

  Widget _buildCaixa(Caixa caixa) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final aberto = caixa.statusCaixa == 1;
    final corStatus = aberto ? cores.success : cores.error;

    return Card(
      elevation: AppElevation.cardRaised,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: corStatus.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                aberto ? Icons.lock_open : Icons.lock,
                size: 18,
                color: corStatus,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _buildDado(
              icone: Icons.calendar_today,
              texto:
                  caixa.dataAbertura != null
                      ? '${caixa.dataAbertura!.day.toString().padLeft(2, '0')}/${caixa.dataAbertura!.month.toString().padLeft(2, '0')}'
                      : 'N/A',
              cor: theme.colorScheme.onSurfaceVariant,
            ),
            const Spacer(),
            _buildDado(
              icone: Icons.account_balance_wallet,
              texto: CurrencyFormatter.format(caixa.saldo),
              cor: cores.success,
              destaque: true,
            ),
            const Spacer(),
            _buildDado(
              icone: Icons.receipt,
              texto: '${caixa.totalPedidoConfirmado ?? 0}',
              cor: cores.info,
              destaque: true,
            ),
            const Spacer(),
            // Abrir o caixa é a ação da linha: usa o azul da marca, e não uma
            // cor avulsa. O laranja anterior não alcançava contraste com o
            // ícone branco em cima.
            Material(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CaixaPage(caixa: caixa),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.search,
                    size: 20,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDado({
    required IconData icone,
    required String texto,
    required Color cor,
    bool destaque = false,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 16, color: cor),
        const SizedBox(width: AppSpacing.xs),
        Text(
          texto,
          style: (destaque
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodySmall)
              ?.copyWith(color: cor),
        ),
      ],
    );
  }
}
