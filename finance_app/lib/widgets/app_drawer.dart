import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/caixa_cache.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/auth_actions.dart';
import '../utils/navegacao.dart';

/// O menu lateral do app.
///
/// **"Caixas" só aparece para quem usa caixa.** Loja que não tem o PDV nunca
/// teve uma linha em `finance_caixa`, e o item levava a uma tela permanentemente
/// vazia — o mesmo motivo que esconde o bloco do caixa no painel. Quem responde
/// é o [CaixaCache], que o painel já semeou: o menu não dispara requisição a
/// cada abertura.
///
/// **Ele vive em três formas, e a [forma] diz qual** ([MenuLateral]): gaveta do
/// `Scaffold`, barra fixa recolhida só com ícones, ou barra fixa com os
/// rótulos. Quem resolve a forma a partir do tamanho da tela é a [MolduraMenu].
///
/// A diferença que importa entre gaveta e fixo não é visual: na gaveta, tocar um
/// item precisa **fechá-la** com um `Navigator.pop`, e fixo esse mesmo `pop`
/// derrubaria a rota em foco — o menu não está sobre nada que se possa fechar.
///
/// Recolhido, nada some do menu: os seis destinos, o tema e o "Sair" continuam
/// todos lá, só que como ícone. O que era rótulo vira `Tooltip` — um ícone sem
/// nome e sem tooltip é um botão que ninguém sabe o que faz.
class AppDrawer extends StatelessWidget {
  /// Injetável para o teste não depender de rede. Nulo — o normal — faz o menu
  /// perguntar ao [CaixaCache].
  final bool? temCaixa;

  /// Gaveta, barra recolhida ou barra expandida.
  final MenuLateral forma;

  /// Recolher/expandir. Nulo esconde o botão: ou é gaveta (não há barra a
  /// recolher), ou a tela não comporta a forma expandida e não há escolha.
  final VoidCallback? onAlternar;

  const AppDrawer({
    super.key,
    this.temCaixa,
    this.forma = MenuLateral.gaveta,
    this.onAlternar,
  });

  bool get _recolhido => forma == MenuLateral.recolhido;

  /// Fecha a gaveta. Fixo, não há gaveta — e o `pop` acertaria a rota.
  void _fecharGaveta(BuildContext context) {
    if (forma.ehFixo) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      width: _recolhido ? AppLayout.larguraMenuColapsado : null,
      // Fixo ele é parte da tela, não está sobre ela: sem sombra, e com o canto
      // direito reto para encostar no divisor em vez de descolar dele.
      elevation: forma.ehFixo ? AppElevation.none : null,
      shape: forma.ehFixo ? const RoundedRectangleBorder() : null,
      child: Column(
        children: [
          _buildCabecalho(context),
          if (onAlternar != null) _buildBotaoAlternar(context),

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
                Divider(
                  height: AppSpacing.xxl,
                  indent: _recolhido ? AppSpacing.md : AppSpacing.lg,
                  endIndent: _recolhido ? AppSpacing.md : AppSpacing.lg,
                ),

                _buildTema(context, themeProvider, isDark),
              ],
            ),
          ),

          // Footer com botão de logout
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(
                _recolhido ? AppSpacing.sm : AppSpacing.lg,
              ),
              child: _buildSair(context, theme),
            ),
          ),
        ],
      ),
    );
  }

  /// A marca. Recolhido sobra só o logo: "Finance App" em 72px de largura
  /// quebraria em duas linhas e o subtítulo não caberia de jeito nenhum.
  Widget _buildCabecalho(BuildContext context) {
    final theme = Theme.of(context);

    final logo = Container(
      width: _recolhido ? 40 : 80,
      height: _recolhido ? 40 : 80,
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
        padding: EdgeInsets.all(_recolhido ? AppSpacing.sm : AppSpacing.lg),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.account_balance_wallet,
              size: _recolhido ? 20 : 40,
              color: theme.colorScheme.primary,
            );
          },
        ),
      ),
    );

    return Container(
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
          padding: EdgeInsets.all(_recolhido ? AppSpacing.lg : AppSpacing.xl),
          child: _recolhido
              ? Center(child: logo)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    logo,
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
    );
  }

  /// Recolher/expandir, logo abaixo da marca.
  ///
  /// Fora do cabeçalho de gradiente de propósito: ele é a identidade do app, e
  /// um botão de layout ali competiria com o logo. Aqui o botão encabeça a
  /// navegação, que é o que ele de fato controla.
  Widget _buildBotaoAlternar(BuildContext context) {
    final theme = Theme.of(context);
    final rotulo = _recolhido ? 'Expandir menu' : 'Recolher menu';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _recolhido ? AppSpacing.sm : AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Align(
        // Expandido ele fica à direita, encostado na borda de onde a barra
        // recolhe; recolhido, centralizado como todo ícone da coluna.
        alignment: _recolhido ? Alignment.center : Alignment.centerRight,
        child: IconButton(
          onPressed: onAlternar,
          tooltip: rotulo,
          icon: Icon(
            _recolhido ? Icons.menu : Icons.menu_open,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTema(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final icone = isDark ? Icons.dark_mode : Icons.light_mode;
    final rotulo = isDark ? 'Tema Escuro' : 'Tema Claro';

    if (_recolhido) {
      return Center(
        child: IconButton(
          onPressed: themeProvider.toggleTheme,
          tooltip: rotulo,
          icon: Icon(icone, color: theme.colorScheme.onSurface),
        ),
      );
    }

    return ListTile(
      leading: Icon(icone, color: theme.colorScheme.onSurface),
      title: Text(rotulo),
      trailing: Switch(
        value: isDark,
        onChanged: (_) => themeProvider.toggleTheme(),
        activeColor: theme.colorScheme.onSurface,
      ),
      onTap: () => themeProvider.toggleTheme(),
    );
  }

  Widget _buildSair(BuildContext context, ThemeData theme) {
    void sair() {
      // Fecha o drawer antes de sair; o popUntil do sairDoApp é sobre a pilha
      // de rotas, não sobre o drawer aberto.
      _fecharGaveta(context);
      sairDoApp(context);
    }

    if (_recolhido) {
      // Quadrado cheio em vez de um `IconButton` solto: "Sair" é destrutivo e
      // precisa continuar lendo como botão, não como mais um destino da lista.
      return Tooltip(
        message: 'Sair',
        child: Material(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: sair,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: const SizedBox(
              height: 48,
              child: Icon(Icons.logout, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: sair,
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

    void ir() {
      // Fecha a gaveta nos dois casos. Fixo isto é no-op, e tocar o item da
      // tela em foco não faz mais nada — quem decide é o `irParaDestino`.
      _fecharGaveta(context);
      irParaDestino(context, route);
    }

    if (_recolhido) {
      // Sem rótulo, o `Tooltip` é a única coisa que nomeia o destino.
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2,
        ),
        child: Tooltip(
          message: title,
          child: Material(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: ir,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 48,
                child: Icon(
                  icon,
                  // A seta que marcava o selecionado não cabe aqui: o que
                  // distingue a tela em foco é o fundo tonal mais a cor do
                  // ícone — nunca só o fundo, que some para quem não distingue
                  // o matiz.
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (iconColor ?? theme.colorScheme.onSurface),
                ),
              ),
            ),
          ),
        ),
      );
    }

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
        onTap: ir,
      ),
    );
  }
}
