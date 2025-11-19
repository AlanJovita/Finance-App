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
        if (idCliente != null) {
          boletos = await apiService.checkBoletos(idCliente);
        }
      } catch (e) {
        // Se falhar ao buscar boletos, apenas ignora e continua
        print('Erro ao buscar boletos: $e');
      }

      setState(() {
        _caixa = caixa;
        _relatorioSemanal = relatorioSemanal;
        _relatoriosMensais = relatoriosMensais;
        _boletos = boletos;
        _isLoading = false;
      });

      // Mostra modal se houver boletos vencidos
      if (boletos.any((b) => b.isOverdue)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOverdueBoletosDialog();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showOverdueBoletosDialog() {
    final boletosVencidos = _boletos.where((b) => b.isOverdue).toList();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 48,
            ),
            title: const Text('Boletos Vencidos'),
            content: Text(
              'Você possui ${boletosVencidos.length} boleto(s) vencido(s).\n\n'
              'Por favor, verifique e regularize sua situação o quanto antes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
    );
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
            const SizedBox(width: 8),
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
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar dados:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildMainCard(context, themeProvider),
                      const SizedBox(height: 16),
                      BoletosWidget(boletos: _boletos),
                      if (_boletos.isNotEmpty) const SizedBox(height: 16),
                      _buildActionCardsRow(context),
                      const SizedBox(height: 16),
                      MonthlyChartsWidget(relatorios: _relatoriosMensais),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildMainCard(BuildContext context, dynamic themeProvider) {
    final caixa = _caixa;
    final theme = Theme.of(context);

    if (caixa == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
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
        elevation: 8.0,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.none,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho com data e botão
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dataFechamento.day.toString().padLeft(2, '0')}/${dataFechamento.month.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _getDiaSemana(dataFechamento.weekday),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CaixaPage(caixa: caixa),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.search,
                          color: theme.colorScheme.onSurface,
                          size: 18,
                        ),
                        label: Text(
                          'Detalhes',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Cards internos com informações
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
                      const SizedBox(width: 12),
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
            // Badge de status como faixa diagonal
            Positioned(
              top: 0,
              right: -40,
              child: Transform.rotate(
                angle: 0.785398, // 45 graus
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusAberto ? Colors.green : Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            statusAberto ? 'Aberto' : 'Fechado',
                            style: const TextStyle(
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
            ),
          ],
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
    // Calcula percentuais
    final percentMedia =
        media > 0 ? ((currentValue - media) / media * 100) : 0.0;
    final percentRecord =
        record > 0 ? ((currentValue - record) / record * 100) : 0.0;

    final isMediaPositive = percentMedia >= 0;
    final isRecordPositive = percentRecord >= 0;
    final isBeatRecord = currentValue >= record && record > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border:
            isBeatRecord
                ? Border.all(color: Colors.amber.withOpacity(0.5), width: 2)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              if (isBeatRecord)
                Icon(Icons.emoji_events, color: Colors.amber, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (estornados != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, color: Colors.orange.shade700, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$estornados',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Comparação com média
          Row(
            children: [
              Icon(
                isMediaPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isMediaPositive ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${CurrencyFormatter.formatSimple(percentMedia.abs(), decimals: 0)}% ${isMediaPositive ? "acima da" : "abaixo da"} média',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMediaPositive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Comparação com record
          Row(
            children: [
              Icon(
                isRecordPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isRecordPositive ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${CurrencyFormatter.formatSimple(percentRecord.abs(), decimals: 0)}% ${isRecordPositive ? "acima do" : "abaixo do"} record',
                  style: TextStyle(
                    fontSize: 11,
                    color: isRecordPositive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCardsRow(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            Icons.view_list,
            '/caixas',
            isDark ? theme.primaryColor : theme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context,
            Icons.arrow_upward,
            '/receitas',
            isDark ? Colors.green[300]! : Colors.green[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context,
            Icons.arrow_downward,
            '/despesas',
            isDark ? Colors.red[300]! : Colors.red[600]!,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String route,
    Color color,
  ) {
    // Define label based on route
    String label = '';
    if (route == '/caixas') {
      label = 'Caixas';
    } else if (route == '/receitas') {
      label = 'Receitas';
    } else if (route == '/despesas') {
      label = 'Despesas';
    }

    return Card(
      elevation: 4.0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 80,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
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
