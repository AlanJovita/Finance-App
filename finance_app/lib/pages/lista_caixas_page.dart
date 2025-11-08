import 'package:finance_app/pages/caixa_page.dart';
import 'package:flutter/material.dart';
import '../models/caixa.dart';
import '../services/api_service.dart';
import '../widgets/charts/caixas_chart_widget.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Caixas')),
      body: FutureBuilder<List<Caixa>>(
        future: _caixasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum caixa encontrado.'));
          }

          final caixas = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CaixasChartWidget(caixas: caixas),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: caixas.length,
                  itemBuilder: (context, index) {
                    final caixa = caixas[index];
                    final animation = Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index / caixas.length) * 0.5,
                          ((index + 1) / caixas.length) * 0.5 + 0.5,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    );

                    final fadeAnimation = Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index / caixas.length) * 0.5,
                          ((index + 1) / caixas.length) * 0.5 + 0.5,
                          curve: Curves.easeIn,
                        ),
                      ),
                    );

                    return SlideTransition(
                      position: animation,
                      child: FadeTransition(
                        opacity: fadeAnimation,
                        child: Card(
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.2),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Status - Lock Icon in circular card
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        caixa.statusCaixa == 1
                                            ? (isDark
                                                    ? Colors.green[300]
                                                    : Colors.green[600])!
                                                .withOpacity(0.15)
                                            : (isDark
                                                    ? Colors.red[300]
                                                    : Colors.red[600])!
                                                .withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    caixa.statusCaixa == 1
                                        ? Icons.lock_open
                                        : Icons.lock,
                                    size: 18,
                                    color:
                                        caixa.statusCaixa == 1
                                            ? (isDark
                                                ? Colors.green[300]
                                                : Colors.green[600])
                                            : (isDark
                                                ? Colors.red[300]
                                                : Colors.red[600]),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Data
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  caixa.dataAbertura != null
                                      ? '${caixa.dataAbertura!.day.toString().padLeft(2, '0')}/${caixa.dataAbertura!.month.toString().padLeft(2, '0')}'
                                      : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                // Saldo
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 16,
                                  color:
                                      isDark
                                          ? Colors.green[300]
                                          : Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'R\$ ${caixa.saldo?.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark
                                            ? Colors.green[300]
                                            : Colors.green[600],
                                  ),
                                ),
                                const Spacer(),
                                // Pedidos
                                Icon(
                                  Icons.receipt,
                                  size: 16,
                                  color:
                                      isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${caixa.totalPedidoConfirmado ?? 0}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark
                                            ? Colors.blue[300]
                                            : Colors.blue[600],
                                  ),
                                ),
                                const Spacer(),
                                // Botão de ação
                                Material(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(6),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  CaixaPage(caixa: caixa),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.search,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
