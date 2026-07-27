import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Slide animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Scale animation for logo
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Animação de loading
      _scaleController.reverse();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _userController.text,
        _passwordController.text,
        _rememberMe,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          // Animação de sucesso
          _scaleController.forward();
        } else {
          // Animação de erro (shake)
          _scaleController.forward();
          _shakeCard();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('Usuário ou senha inválidos.')),
                ],
              ),
              backgroundColor: context.appColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          );
        }
      }
    }
  }

  void _shakeCard() {
    _slideController.reset();
    _slideController.forward();
  }

  /// Os campos do login são sem borda, sobre um preenchimento sólido — um visual
  /// próprio, diferente do `inputDecorationTheme` do resto do app. Fica num
  /// helper para os dois campos não repetirem 30 linhas de borda cada.
  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final semBorda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icone),
      suffixIcon: suffixIcon,
      border: semBorda,
      enabledBorder: semBorda,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
      ),
      filled: true,
      fillColor: theme.colorScheme.surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.secondary.withValues(alpha: 0.6),
              theme.colorScheme.tertiary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: AppSpacing.lg,
              right: AppSpacing.lg,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildVersao(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: _buildCard(),
                      ),
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

  Widget _buildVersao() {
    final theme = Theme.of(context);
    // O texto fica sobre o gradiente da marca nos dois modos, então a tinta é
    // branca sempre — não é o fundo do tema que está atrás dele.
    final cor = Colors.white.withValues(alpha: 0.9);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, size: 16, color: cor),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'v1.0.0',
          style: theme.textTheme.labelMedium?.copyWith(
            color: cor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 20.0,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl - AppSpacing.sm),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Hero(tag: 'app_logo', child: _buildLogo()),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Text(
                'Finance App',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Faça login para continuar',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              TextFormField(
                controller: _userController,
                decoration: _decoracaoCampo(
                  label: 'Usuário',
                  icone: Icons.person_outline,
                ),
                validator:
                    (value) =>
                        (value == null || value.isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.xl),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _decoracaoCampo(
                  label: 'Senha',
                  icone: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator:
                    (value) =>
                        (value == null || value.isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() => _rememberMe = value ?? false);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                    ),
                  ),
                  Text('Lembrar login', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // TODO: Implementar recuperação de senha
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Funcionalidade em desenvolvimento'),
                        ),
                      );
                    },
                    child: const Text('Esqueceu a senha?'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              _buildBotaoEntrar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotaoEntrar() {
    if (_isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _login,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Entrar'),
            SizedBox(width: AppSpacing.sm),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.account_balance_wallet,
                    size: 60,
                    color: theme.colorScheme.primary,
                  );
                },
              ),
            ),
          ),
        ),
        // Selo no canto: o anel usa a cor do card, que é o que está atrás dele.
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cores.success,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.surfaceContainerHighest,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.attach_money,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
