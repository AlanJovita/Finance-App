import 'package:finance_app/utils/currency_formatter.dart';
import 'package:finance_app/widgets/fluxo_form_dialog.dart';
import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
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
    filtro: 'tipo_fluxo=1',
    tipoDialogo: 'receita',
    icone: Icons.attach_money,
  ),
  despesa(
    titulo: 'Despesas',
    singular: 'despesa',
    filtro: 'tipo_fluxo=2',
    tipoDialogo: 'despesa',
    icone: Icons.remove_circle_outline,
  );

  const TipoFluxo({
    required this.titulo,
    required this.singular,
    required this.filtro,
    required this.tipoDialogo,
    required this.icone,
  });

  /// Título da tela, no plural.
  final String titulo;

  /// Nome no singular, para textos como "Nova receita".
  final String singular;

  /// Filtro enviado para `listFluxos`.
  final String filtro;

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
  late Future<List<FluxoCaixa>> _fluxosFuture;
  final ApiService _apiService = ApiService();
  List<dynamic> _categorias = [];
  final Set<String> _expandedMonths = {};

  TipoFluxo get _tipo => widget.tipo;

  @override
  void initState() {
    super.initState();
    _loadFluxos();
    _loadCategorias();
    // Expande o mês atual por padrão
    final now = DateTime.now();
    _expandedMonths.add('${now.year}-${now.month}');
  }

  void _loadFluxos() {
    setState(() {
      _fluxosFuture = _apiService.listFluxos(_tipo.filtro);
    });
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

  String _getMonthYearKey(DateTime? date) {
    if (date == null) return 'sem-data';
    return '${date.year}-${date.month}';
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

  Map<String, List<FluxoCaixa>> _groupByMonth(List<FluxoCaixa> fluxos) {
    final Map<String, List<FluxoCaixa>> grouped = {};

    for (var fluxo in fluxos) {
      final key = _getMonthYearKey(fluxo.dataVencimento);
      grouped.putIfAbsent(key, () => []).add(fluxo);
    }

    return grouped;
  }

  List<String> _getSortedMonthKeys(Map<String, List<FluxoCaixa>> grouped) {
    final keys = grouped.keys.toList();
    keys.sort((a, b) {
      if (a == 'sem-data') return 1;
      if (b == 'sem-data') return -1;

      final partsA = a.split('-');
      final partsB = b.split('-');
      final dateA = DateTime(int.parse(partsA[0]), int.parse(partsA[1]));
      final dateB = DateTime(int.parse(partsB[0]), int.parse(partsB[1]));

      return dateB.compareTo(dateA); // Mais novo primeiro
    });

    return keys;
  }

  void _showFormDialog({FluxoCaixa? fluxo}) {
    showDialog(
      context: context,
      builder: (context) {
        return FluxoFormDialog(
          tipoFluxo: _tipo.tipoDialogo,
          fluxo: fluxo,
          onSave: () {
            _loadFluxos();
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
      _loadFluxos();
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
      body: FutureBuilder<List<FluxoCaixa>>(
        future: _fluxosFuture,
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

          final fluxos = snapshot.data!;

          // Ordena por data (mais nova primeiro)
          fluxos.sort((a, b) {
            if (a.dataVencimento == null) return 1;
            if (b.dataVencimento == null) return -1;
            return b.dataVencimento!.compareTo(a.dataVencimento!);
          });

          final grouped = _groupByMonth(fluxos);
          final sortedMonthKeys = _getSortedMonthKeys(grouped);

          return ListView.builder(
            padding: context.responsivePadding(),
            itemCount: sortedMonthKeys.length,
            itemBuilder: (context, index) {
              final monthKey = sortedMonthKeys[index];
              final doMes = grouped[monthKey]!;

              return _buildMes(monthKey, doMes);
            },
          );
        },
      ),
    );
  }

  Widget _buildMes(String monthKey, List<FluxoCaixa> doMes) {
    final isExpanded = _expandedMonths.contains(monthKey);
    final totalMes = doMes.fold<double>(0.0, (sum, f) => sum + (f.valor ?? 0.0));

    String monthLabel;
    if (monthKey == 'sem-data') {
      monthLabel = 'Sem data';
    } else {
      final parts = monthKey.split('-');
      monthLabel = _getMonthYearLabel(
        DateTime(int.parse(parts[0]), int.parse(parts[1])),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCabecalhoMes(monthKey, monthLabel, totalMes, doMes.length, isExpanded),
        if (isExpanded) ...doMes.map(_buildItem),
      ],
    );
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
