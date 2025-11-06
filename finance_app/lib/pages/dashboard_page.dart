import 'package:finance_app/pages/caixa_page.dart';
import 'package:finance_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 600;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                alignment: WrapAlignment.center,
                children: [
                  _buildDashboardCard(
                    context,
                    'Último Caixa',
                    Icons.point_of_sale,
                    '/caixa/ultimo',
                    isDesktop,
                  ), // Rota ainda não implementada
                  _buildDashboardCard(
                    context,
                    'Lista de Caixas',
                    Icons.view_list,
                    '/caixas',
                    isDesktop,
                  ),
                  _buildDashboardCard(
                    context,
                    'Receitas',
                    Icons.arrow_upward,
                    '/receitas',
                    isDesktop,
                  ),
                  _buildDashboardCard(
                    context,
                    'Despesas',
                    Icons.arrow_downward,
                    '/despesas',
                    isDesktop,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    bool isDesktop,
  ) {
    return SizedBox(
      width: isDesktop ? 250 : double.infinity,
      height: 150,
      child: Card(
        elevation: 4.0,
        child: InkWell(
          onTap: () async {
            if (route != '/caixa/ultimo') {
              Navigator.pushNamed(context, route);
            } else {
              try {
                // Mostra um indicador de carregamento
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Buscando último caixa...')),
                );
                final caixa = await ApiService().getCaixa();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CaixaPage(caixa: caixa),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao buscar último caixa: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48.0, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16.0),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
