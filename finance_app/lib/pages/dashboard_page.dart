import 'package:finance_app/models/boleto.dart';
import 'package:finance_app/models/caixa.dart';
import 'package:finance_app/models/categoria.dart';
import 'package:finance_app/models/relatorio_mensal.dart';
import 'package:finance_app/models/relatorio_semanal.dart';
import 'package:finance_app/models/resumo_painel.dart';
import 'package:finance_app/pages/caixa_page.dart';
import 'package:finance_app/services/api_service.dart';
import 'package:finance_app/services/caixa_cache.dart';
import 'package:finance_app/services/global_state.dart';
import 'package:finance_app/services/logger_service.dart';
import 'package:finance_app/utils/auth_actions.dart';
import 'package:finance_app/utils/currency_formatter.dart';
import 'package:finance_app/widgets/boletos_widget.dart';
import 'package:finance_app/widgets/cartoes_movimentacoes.dart';
import 'package:finance_app/widgets/charts/cartao_grafico_mensal.dart';
import 'package:finance_app/widgets/grade_cartoes.dart';
import 'package:finance_app/widgets/moldura_menu.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_widgets.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/responsive_utils.dart';

/// O painel tem **dois resumos independentes**, e cada um aparece só se tiver
/// assunto: o do caixa da loja e o das receitas e despesas.
///
/// Quem não usa o PDV não tem linha nenhuma em `finance_caixa`, e o bloco do
/// caixa aparecia como um card "Nenhum caixa disponível" seguido de dois
/// gráficos vazios — o painel abria afirmando que não havia nada, para uma loja
/// que lança contas todo dia. Quem usa o PDV e não lança conta nenhuma tinha o
/// problema espelhado.
///
/// O sinal de cada bloco é a ausência de dado, não uma configuração: `getCaixa`
/// devolve `null` quando a loja nunca abriu caixa, e [ResumoPainel.vazio] diz
/// que nunca houve lançamento. Ordem fixa quando os dois existem — caixa
/// primeiro, movimentações depois.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final LoggerService _logger = LoggerService();
  final ApiService _apiService = ApiService();

  Caixa? _caixa;
  RelatorioSemanal? _relatorioSemanal;
  List<RelatorioMensal> _relatoriosMensais = [];
  List<Boleto> _boletos = [];

  ResumoPainel? _painel;
  Map<int, Categoria> _categorias = {};

  bool _isLoading = true;

  /// Falha de cada bloco, separada de propósito: a do caixa não pode apagar as
  /// movimentações da tela, nem o contrário. O erro de tela inteira só aparece
  /// quando os **dois** falharam — ver [_error].
  Object? _erroCaixa;
  Object? _erroMovimentacoes;

  /// Nada carregou. É o único caso que troca o painel pela tela de erro.
  String? get _error => (_erroCaixa != null && _erroMovimentacoes != null)
      ? _erroCaixa.toString()
      : null;

  /// A loja tem caixa — e, com ele, faturamento e pedidos para comparar.
  bool get _temCaixa => _caixa != null;

  bool get _temMovimentacoes => _painel != null && !_painel!.vazio;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _erroCaixa = null;
      _erroMovimentacoes = null;
    });

    // Em paralelo: são três grupos independentes e o painel é a primeira tela
    // depois do login. Em série, o tempo de abertura era a soma de todos.
    await Future.wait([
      _carregarCaixa(),
      _carregarMovimentacoes(),
      _carregarBoletos(),
    ]);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _carregarCaixa() async {
    try {
      final caixa = await _apiService.getCaixa();
      final relatoriosSemana = await _apiService.getRelatorioSemanal();
      final relatoriosMensais = await _apiService.getRelatorioMensal(
        DateTime.now().year,
      );

      // Relatório do dia da semana atual (1 = segunda, 7 = domingo).
      final diaSemana = DateTime.now().weekday;
      RelatorioSemanal? relatorioSemanal;

      if (relatoriosSemana.isNotEmpty) {
        relatorioSemanal = relatoriosSemana.firstWhere(
          (r) => r.diaSemana == diaSemana,
          orElse: () => relatoriosSemana.first,
        );
      }

      // O menu lateral esconde "Caixas" pela mesma resposta, e é aqui que ele
      // fica sabendo — sem isto, abrir o menu dispararia um `getCaixa` próprio.
      CaixaCache().semear(temCaixa: caixa != null);

      if (!mounted) return;
      setState(() {
        _caixa = caixa;
        _relatorioSemanal = relatorioSemanal;
        _relatoriosMensais = relatoriosMensais;
      });
    } catch (e, s) {
      await _logger.logError('DashboardPage._carregarCaixa', e, stackTrace: s);
      if (!mounted) return;
      setState(() => _erroCaixa = e);
    }
  }

  /// O painel inteiro numa requisição, mais o mapa de categorias.
  ///
  /// As categorias vêm à parte porque o agrupamento da API devolve só
  /// `id_categoria`: nome, cor e ícone saem daqui, e são os mesmos que as telas
  /// de Receitas e Despesas usam.
  Future<void> _carregarMovimentacoes() async {
    try {
      final painel = await _apiService.getResumoPainel();

      // Categoria é acessório do painel: sem ela as fatias viram "Sem
      // categoria" e a tela continua de pé. Falhar aqui não pode esconder os
      // números.
      Map<int, Categoria> categorias = {};
      try {
        final lista = await _apiService.listCategorias();
        categorias = {
          for (final c in lista)
            if (c.id != null) c.id!: c,
        };
      } catch (e, s) {
        debugPrint('Erro ao carregar categorias do painel: $e');
        await _logger.logError(
          'DashboardPage._carregarMovimentacoes.categorias',
          e,
          stackTrace: s,
        );
      }

      if (!mounted) return;
      setState(() {
        _painel = painel;
        _categorias = categorias;
      });
    } catch (e, s) {
      await _logger.logError(
        'DashboardPage._carregarMovimentacoes',
        e,
        stackTrace: s,
      );
      if (!mounted) return;
      setState(() => _erroMovimentacoes = e);
    }
  }

  /// Boleto é um bloco do painel, não o painel: a falha não interrompe o resto
  /// do carregamento, só sai no log.
  Future<void> _carregarBoletos() async {
    try {
      final idCliente = GlobalState().firstIdLoja;
      if (idCliente == 0) return;

      final boletos = await _apiService.checkBoletos(idCliente);

      if (!mounted) return;
      setState(() => _boletos = boletos);
    } catch (e, s) {
      debugPrint('Erro ao buscar boletos: $e');
      await _logger.logError(
        'DashboardPage._carregarBoletos',
        e,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MolduraMenu(
      builder: (context, menuFixo) =>
          _buildScaffold(context, themeProvider, menuFixo),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ThemeProvider themeProvider,
    bool menuFixo,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(_caixa?.nomeLoja ?? 'Resumo'),
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
            onPressed: () => sairDoApp(context),
            tooltip: 'Sair',
          ),
        ],
      ),
      drawer: menuFixo ? null : const AppDrawer(),
      body: _isLoading
          ? ShimmerWidgets.dashboardFullShimmer(context)
          : _error != null
          ? _buildErro()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.responsivePadding(),
                child: _buildConteudo(context),
              ),
            ),
    );
  }

  /// Os cards do Resumo, montados uma vez e distribuídos pela
  /// [GradeCartoes] em 1, 2 ou 3 colunas conforme a largura da tela
  /// ([AppLayout.colunasResumo]).
  ///
  /// **Todo card é peça solta.** Não há mais "bloco do caixa" e "bloco de
  /// movimentações" como unidades de layout: os dois gráficos mensais e os cinco
  /// cards de movimentações entram aqui individualmente. Eram justamente esses
  /// dois agrupamentos que faziam uma coluna ficar com 1800px de altura e a
  /// outra com 300 — a grade só consegue equilibrar o que recebe em pedaços.
  ///
  /// **A ordem desta lista ainda decide o essencial**, porque a grade põe os
  /// primeiros cards no topo de cada coluna, na ordem recebida, e só distribui o
  /// resto por altura. É a mesma ordem de sempre numa coluna: caixa, boletos,
  /// atalhos, gráficos do caixa, e depois as movimentações. Os dois pedaços do
  /// caixa continuam não contíguos de propósito — boletos e atalhos ficam entre
  /// eles, porque agrupá-los empurraria o aviso de boleto vencendo para baixo
  /// de dois gráficos.
  Widget _buildConteudo(BuildContext context) {
    final espaco = context.responsiveSpacing();

    // O menu fixo come 304px, e nasce exatamente na largura que seria o piso de
    // três colunas: sem descontá-lo, uma tela de 1500px montaria três colunas
    // mais estreitas que as duas de um celular deitado.
    final colunas = AppLayout.colunasResumo(
      AppLayout.larguraUtil(MediaQuery.sizeOf(context).width),
    );
    final painel = _painel;

    final cartoes = <Widget>[
      if (_caixa != null) _buildMainCard(context, _caixa!),
      if (_boletos.isNotEmpty) BoletosWidget(boletos: _boletos),
      _buildActionCardsRow(context),

      // Faturamento e pedidos saem do caixa: sem caixa seriam dois gráficos
      // vazios.
      if (_temCaixa && _relatoriosMensais.isNotEmpty) ...[
        CartaoGraficoMensal(
          relatorios: _relatoriosMensais,
          grafico: GraficoMensal.faturamento,
        ),
        CartaoGraficoMensal(
          relatorios: _relatoriosMensais,
          grafico: GraficoMensal.pedidos,
        ),
      ],

      if (_temMovimentacoes && painel != null) ...[
        CartaoSaldos(painel: painel),
        CartaoNatureza(
          painel: painel,
          categorias: _categorias,
          ehReceita: true,
        ),
        CartaoNatureza(
          painel: painel,
          categorias: _categorias,
          ehReceita: false,
        ),
        CartaoCategorias(
          painel: painel,
          categorias: _categorias,
          ehReceita: true,
        ),
        CartaoCategorias(
          painel: painel,
          categorias: _categorias,
          ehReceita: false,
        ),
      ],

      // Um bloco que falhou avisa no lugar dele, em vez de sumir — sumir é o
      // que o Resumo faz quando a loja de fato não tem o dado, e os dois casos
      // não podem parecer iguais.
      if (_erroCaixa != null)
        _buildFalhaBloco('Não foi possível carregar o resumo do caixa.'),
      if (_erroMovimentacoes != null)
        _buildFalhaBloco('Não foi possível carregar as movimentações.'),
      if (!_temCaixa &&
          !_temMovimentacoes &&
          _erroCaixa == null &&
          _erroMovimentacoes == null)
        _buildSemDados(context),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.conteudoMaximo),
        child: GradeCartoes(colunas: colunas, espaco: espaco, cartoes: cartoes),
      ),
    );
  }

  /// Estado vazio de verdade: a loja não tem caixa **nem** lançamento. Antes
  /// disto a tela ficava com um card "Nenhum caixa disponível" e dois gráficos
  /// em branco, que parecem falha de carregamento.
  Widget _buildSemDados(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nada para resumir ainda',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lance uma receita ou uma despesa e o resumo aparece aqui.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFalhaBloco(String mensagem) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 20, color: cores.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(mensagem, style: theme.textTheme.bodySmall)),
            TextButton(
              onPressed: _loadData,
              child: const Text('Tentar de novo'),
            ),
          ],
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
          Text('Erro ao carregar dados:\n$_error', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  /// Recebe o caixa já resolvido: quem decide se o bloco existe é
  /// [_temCaixa], e o card não precisa ter um estado "sem caixa" — era ele que
  /// aparecia escrito "Nenhum caixa disponível" para quem nunca usou o PDV.
  Widget _buildMainCard(BuildContext context, Caixa caixa) {
    final theme = Theme.of(context);

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
        elevation: AppElevation.none,
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
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurface, size: 18),
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
          decoration: BoxDecoration(color: cor),
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
    final percentMedia = media > 0
        ? ((currentValue - media) / media * 100)
        : 0.0;
    final percentRecord = record > 0
        ? ((currentValue - record) / record * 100)
        : 0.0;

    final isBeatRecord = currentValue >= record && record > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isBeatRecord
            ? Border.all(color: cores.warning.withValues(alpha: 0.5), width: 2)
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

          _buildComparacao(percentMedia, isMedia: true),
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
    final preposicao = isMedia
        ? (positivo ? 'acima da' : 'abaixo da')
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

  /// Os atalhos. "Caixas" acompanha o bloco do caixa: sem caixa ele levaria a
  /// uma tela permanentemente vazia, e o menu lateral esconde o item pelo mesmo
  /// motivo. Receitas e Despesas ficam sempre — são o que toda loja usa.
  /// Caixas, Receitas e Despesas.
  ///
  /// Com teto de largura e alinhados à esquerda: esticados por 1900px eles
  /// viravam três faixas coloridas de 600px cada, que é tamanho de banner, não
  /// de atalho. O teto também os mantém com a mesma proporção nas duas colunas
  /// e numa só.
  Widget _buildActionCardsRow(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Row(
          children: [
            if (_temCaixa) ...[
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
            ],
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
        ),
      ),
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
      elevation: AppElevation.none,
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
