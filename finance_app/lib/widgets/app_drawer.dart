import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/caixa_cache.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/auth_actions.dart';

/// O menu lateral do app.
///
/// **"Caixas" só aparece para quem usa caixa.** Loja que não tem o PDV nunca
/// teve uma linha em `finance_caixa`, e o item levava a uma tela permanentemente
/// vazia — o mesmo motivo que esconde o bloco do caixa no painel. Quem responde
/// é o [CaixaCache], que o painel já semeou: o menu não dispara requisição a
/// cada abertura.
///
/// **Ele vive em dois lugares, e o [fixo] é quem diz qual.** Como gaveta do
/// `Scaffold` (o padrão) e, acima de [AppLayout.menuFixo], encostado na lateral
/// pela [MolduraMenu]. A diferença que importa não é visual: na gaveta, tocar um
/// item precisa **fechá-la** com um `Navigator.pop`, e fixo esse mesmo `pop`
/// derrubaria a rota em foco — o menu não está sobre nada que se possa fechar.
class AppDrawer extends StatelessWidget {
  /// Injetável para o teste não depender de rede. Nulo — o normal — faz o menu
  /// perguntar ao [CaixaCache].
  final bool? temCaixa;

  /// Encostado na lateral em vez de aberto como gaveta.
  final bool fixo;

  const AppDrawer({super.key, this.temCaixa, this.fixo = false});

  /// Fecha a gaveta. Fixo, não há gaveta — e o `pop` acertaria a rota.
  void _fecharGaveta(BuildContext context) {
    if (fixo) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      // Fixo ele é parte da tela, não está sobre ela: sem sombra, e com o canto
      // direito reto para encostar no divisor em vez de descolar dele.
      elevation: fixo ? AppElevation.none : null,
      shape: fixo ? const RoundedRectangleBorder() : null,
      child: Column(
        children: [
          // Header do Drawer com logo e gradiente
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                  theme.colorScheme.tertiary,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo circular
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.account_balance_wallet,
                              size: 40,
                              color: theme.colorScheme.primary,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Finance App',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Controle Financeiro',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: AppSpacing.sm),
                _buildMenuItem(
                  context,
                  icon: Icons.dashboard,
                  title: 'Resumo',
                  route: '/dashboard',
                ),
                _itemCaixas(context),
                _buildMenuItem(
                  context,
                  icon: Icons.account_balance,
                  title: 'Contas',
                  route: '/contas',
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.credit_card,
                  title: 'Cartões',
                  route: '/cartoes',
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.arrow_upward,
                  title: 'Receitas',
                  route: '/receitas',
                  iconColor: context.appColors.success,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.arrow_downward,
                  title: 'Despesas',
                  route: '/despesas',
                  iconColor: context.appColors.error,
                ),
                const Divider(
                  height: AppSpacing.xxl,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                ),

                // Toggle de tema
                ListTile(
                  leading: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: Text(isDark ? 'Tema Escuro' : 'Tema Claro'),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => themeProvider.toggleTheme(),
                    activeColor: theme.colorScheme.onSurface,
                  ),
                  onTap: () => themeProvider.toggleTheme(),
                ),
              ],
            ),
          ),

          // Footer com botão de logout
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Fecha o drawer antes de sair; o popUntil do sairDoApp é
                  // sobre a pilha de rotas, não sobre o drawer aberto.
                  _fecharGaveta(context);
                  sairDoApp(context);
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Sair'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Caixas", quando a loja usa caixa.
  ///
  /// Enquanto a resposta não chegou o item **não** é desenhado, e não o
  /// contrário: mostrá-lo e removê-lo meio segundo depois tiraria a opção de
  /// baixo do dedo de quem já estava tocando nela. Na prática o painel semeia o
  /// cache antes de o menu existir, e o `FutureBuilder` resolve no primeiro
  /// frame.
  Widget _itemCaixas(BuildContext context) {
    final item = _buildMenuItem(
      context,
      icon: Icons.view_list,
      title: 'Caixas',
      route: '/caixas',
    );

    final forcado = temCaixa;
    if (forcado != null) {
      return forcado ? item : const SizedBox.shrink();
    }

    final cache = CaixaCache();
    final conhecido = cache.temCaixa;
    if (conhecido != null) {
      return conhecido ? item : const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: cache.obter(),
      builder: (context, snapshot) =>
          snapshot.data == true ? item : const SizedBox.shrink(),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isSelected = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? theme.colorScheme.onSurface),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.primary,
              )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        onTap: () {
          if (currentRoute != route) {
            _fecharGaveta(context);
            // Troca a tela em foco **preservando a raiz**, que é o
            // `AuthWrapper`. Com `pushReplacementNamed` a primeira navegação
            // pelo menu substituía a própria raiz: a pilha ficava com a tela
            // interna no lugar do wrapper, e aí o `popUntil(isFirst)` de quem
            // volta ao login (`auth_actions.dart`, `GuardaSessao`) caía na
            // própria tela interna em vez da tela de login.
            Navigator.pushNamedAndRemoveUntil(
              context,
              route,
              (rota) => rota.isFirst,
            );
          } else {
            // Tocar o item da tela em foco só fecha a gaveta. Fixo, não há o
            // que fechar nem para onde ir — o toque não faz nada.
            _fecharGaveta(context);
          }
        },
      ),
    );
  }
}
