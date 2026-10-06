import 'package:finance_app/utils/currency_formatter.dart';
import 'package:finance_app/widgets/fluxo_form_dialog.dart';
import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
import '../models/resumo_fluxo.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_widgets.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/responsive_utils.dart';

/// Receitas e despesas são a mesma tela: mudam o filtro da API, o rótulo, o
/// ícone e a cor. Antes eram dois arquivos de ~530 linhas quase idênticos.
enum TipoFluxo {
  receita(
    titulo: 'Receitas',
    singular: 'receita',
    codigo: 1,
    tipoDialogo: 'receita',
    icone: Icons.attach_money,
  ),
  despesa(
    titulo: 'Despesas',
    singular: 'despesa',
    codigo: 2,
    tipoDialogo: 'despesa',
    icone: Icons.remove_circle_outline,
  );

  const TipoFluxo({
    required this.titulo,
    required this.singular,
    required this.codigo,
    required this.tipoDialogo,
    required this.icone,
  });

  /// Título da tela, no plural.
  final String titulo;

  /// Nome no singular, para textos como "Nova receita".
  final String singular;

  /// Valor de `tipo_fluxo` na API: 1 entrada, 2 saída.
  final int codigo;

  /// Valor esperado por [FluxoFormDialog].
  final String tipoDialogo;

  final IconData icone;

  /// Entrada de valor é sucesso; saída é erro.
  Color cor(AppColors cores) =>
      this == TipoFluxo.receita ? cores.success : cores.error;
}

class FluxosPage extends StatefulWidget {
  final TipoFluxo tipo;

  const FluxosPage({super.key, required this.tipo});

  @override
  State<FluxosPage> createState() => _FluxosPageState();
}

class _FluxosPageState extends State<FluxosPage> {
  late Future<List<ResumoMes>> _mesesFuture;
  final ApiService _apiService = ApiService();
  List<dynamic> _categorias = [];
  final Set<String> _expandedMonths = {};

  /// Lançamentos já carregados, por mês. Um mês só entra aqui quando é aberto —
  /// é o que evita baixar o histórico inteiro da loja para montar a tela.
  final Map<String, List<FluxoCaixa>> _itensPorMes = {};
  final Set<String> _carregando = {};
  final Map<String, Object> _erroPorMes = {};

  TipoFluxo get _tipo => widget.tipo;

  @override
  void initState() {
    super.initState();
    _loadMeses();
    _loadCategorias();
    // Expande o mês atual por padrão
    final now = DateTime.now();
    _expandedMonths.add('${now.year}-${now.month}');
  }

  void _loadMeses() {
    setState(() {
      _itensPorMes.clear();
      _erroPorMes.clear();
      _mesesFuture = _apiService.getResumoMensal(tipo: _tipo.codigo);
    });
  }

  /// Recarrega o que está na tela depois de criar, editar ou excluir: os totais
  /// dos meses mudam, e os meses abertos precisam refletir a alteração.
  void _recarregar() {
    final abertos = Set<String>.from(_expandedMonths);
    _loadMeses();
    for (final chave in abertos) {
      _carregarMes(chave);
    }
  }

  Future<void> _carregarMes(String chave) async {
    if (_carregando.contains(chave)) return;

    setState(() {
      _carregando.add(chave);
      _erroPorMes.remove(chave);
    });

    try {
      // "Sem data" não tem intervalo: vem sem recorte e o servidor devolve os
      // lançamentos sem vencimento junto — por isso o filtro local abaixo.
      final (de, ate) = _intervaloDoMes(chave);

      final pagina = await _apiService.listFluxosPagina(
        tipo: _tipo.codigo,
        de: de,
        ate: ate,
        porPagina: 500,
      );

      var itens = pagina.itens;
      if (chave == 'sem-data') {
        itens = itens.where((f) => f.dataVencimento == null).toList();
      }

      if (!mounted) return;
      setState(() => _itensPorMes[chave] = itens);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroPorMes[chave] = e);
    } finally {
      if (mounted) setState(() => _carregando.remove(chave));
    }
  }

  /// Primeiro e último dia do mês da chave `ano-mes`.
  (DateTime?, DateTime?) _intervaloDoMes(String chave) {
    if (chave == 'sem-data') return (null, null);

    final partes = chave.split('-');
    final ano = int.parse(partes[0]);
    final mes = int.parse(partes[1]);

    // Dia 0 do mês seguinte é o último dia deste — evita a tabela de 28/30/31.
    return (DateTime(ano, mes, 1), DateTime(ano, mes + 1, 0));
  }

  Future<void> _loadCategorias() async {
    try {
      final categorias = await _apiService.listCategorias();
      setState(() {
        _categorias = categorias;
      });
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
    }
  }

  String _getCategoriaNome(int? idCategoria) {
    if (idCategoria == null || idCategoria == 0) return '';
    try {
      final categoria = _categorias.firstWhere((cat) => cat.id == idCategoria);
      return categoria.nome ?? '';
    } catch (e) {
      return '';
    }
  }

  String _getMonthYearLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showFormDialog({FluxoCaixa? fluxo}) {
    showDialog(
      context: context,
      builder: (context) {
        return FluxoFormDialog(
          tipoFluxo: _tipo.tipoDialogo,
          fluxo: fluxo,
          onSave: () {
            _recarregar();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _confirmarExclusao(FluxoCaixa fluxo) async {
    final cores = context.appColors;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar exclusão'),
            content: Text('Deseja realmente excluir "${fluxo.descricao}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: cores.error),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _apiService.deleteFluxo(fluxo.id!, fluxo.idRef ?? 0);
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tipo.titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showFormDialog(),
            tooltip: 'Nova ${_tipo.singular}',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<ResumoMes>>(
        future: _mesesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ShimmerWidgets.listFluxosShimmer(context);
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('Nenhuma ${_tipo.singular} encontrada.'),
            );
          }

          // Já vem agregado e ordenado do banco: nada a somar nem classificar.
          final meses = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView.builder(
              padding: context.responsivePadding(),
              itemCount: meses.length,
              itemBuilder: (context, index) => _buildMes(meses[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMes(ResumoMes mes) {
    final chave = mes.chave;
    final isExpanded = _expandedMonths.contains(chave);

    final label =
        mes.semData
            ? 'Sem data'
            : _getMonthYearLabel(DateTime(mes.ano!, mes.mes!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCabecalhoMes(
          chave,
          label,
          mes.total,
          mes.quantidade,
          isExpanded,
        ),
        if (isExpanded) ..._buildConteudoMes(chave),
      ],
    );
  }

  /// Corpo de um mês aberto: carregando, erro ou os lançamentos.
  List<Widget> _buildConteudoMes(String chave) {
    if (_carregando.contains(chave)) {
      return [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final erro = _erroPorMes[chave];
    if (erro != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(child: Text('Erro ao carregar: $erro')),
              TextButton(
                onPressed: () => _carregarMes(chave),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ];
    }

    return (_itensPorMes[chave] ?? const <FluxoCaixa>[]).map(_buildItem).toList();
  }

  Widget _buildCabecalhoMes(
    String monthKey,
    String label,
    double total,
    int quantidade,
    bool isExpanded,
  ) {
    final theme = Theme.of(context);
    final cor = _tipo.cor(context.appColors);
    // O contador é um texto sobre a cor cheia: a tinta legível depende de quão
    // clara a cor é, e isso muda entre os modos.
    final sobreCor =
        ThemeData.estimateBrightnessForColor(cor) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedMonths.remove(monthKey);
          } else {
            _expandedMonths.add(monthKey);
          }
        });
        // Busca os lançamentos na primeira abertura; depois ficam em memória.
        if (!isExpanded && !_itensPorMes.containsKey(monthKey)) {
          _carregarMes(monthKey);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              color: cor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(color: cor),
              ),
            ),
            Text(
              CurrencyFormatter.format(total),
              style: theme.textTheme.titleSmall?.copyWith(color: cor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '$quantidade',
                style: theme.textTheme.labelMedium?.copyWith(color: sobreCor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(FluxoCaixa fluxo) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final cor = _tipo.cor(cores);
    final categoriaNome = _getCategoriaNome(fluxo.idCategoria);

    String dataFormatada = '';
    if (fluxo.dataVencimento != null) {
      final day = fluxo.dataVencimento!.day.toString().padLeft(2, '0');
      final month = fluxo.dataVencimento!.month.toString().padLeft(2, '0');
      dataFormatada = '$day/$month';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: () => _showFormDialog(fluxo: fluxo),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_tipo.icone, color: cor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fluxo.descricao ?? 'Sem descrição',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (categoriaNome.isNotEmpty)
                      Text(
                        categoriaNome,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        fluxo.confirmado == true ? 'Confirmado' : 'Pendente',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              fluxo.confirmado == true
                                  ? cores.success
                                  : cores.warning,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(fluxo.valor),
                    style: theme.textTheme.titleMedium?.copyWith(color: cor),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        dataFormatada.isNotEmpty ? dataFormatada : 'S/ data',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildMenu(fluxo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(FluxoCaixa fluxo) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (value) async {
        if (value == 'edit') {
          _showFormDialog(fluxo: fluxo);
        } else if (value == 'delete') {
          await _confirmarExclusao(fluxo);
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20, color: cores.info),
                  const SizedBox(width: AppSpacing.md),
                  const Text('Editar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: cores.error),
                  const SizedBox(width: AppSpacing.md),
                  const Text('Excluir'),
                ],
              ),
            ),
          ],
    );
  }
}
