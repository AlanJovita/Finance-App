import 'package:finance_app/utils/currency_formatter.dart';
import 'package:finance_app/widgets/fluxo_form_dialog.dart';
import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
import '../services/api_service.dart';

class ReceitasPage extends StatefulWidget {
  const ReceitasPage({super.key});
  @override
  State<ReceitasPage> createState() => _ReceitasPageState();
}

class _ReceitasPageState extends State<ReceitasPage> {
  late Future<List<FluxoCaixa>> _receitasFuture;
  final ApiService _apiService = ApiService();
  List<dynamic> _categorias = [];
  final Set<String> _expandedMonths = {};

  @override
  void initState() {
    super.initState();
    _loadReceitas();
    _loadCategorias();
    // Expande o mês atual por padrão
    final now = DateTime.now();
    _expandedMonths.add('${now.year}-${now.month}');
  }

  void _loadReceitas() {
    setState(() {
      _receitasFuture = _apiService.listFluxos("tipo_fluxo=1");
    });
  }

  Future<void> _loadCategorias() async {
    try {
      final categorias = await _apiService.listCategorias();
      setState(() {
        _categorias = categorias;
      });
    } catch (e) {
      print('Erro ao carregar categorias: $e');
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

  Map<String, List<FluxoCaixa>> _groupByMonth(List<FluxoCaixa> receitas) {
    final Map<String, List<FluxoCaixa>> grouped = {};

    for (var receita in receitas) {
      final key = _getMonthYearKey(receita.dataVencimento);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(receita);
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
          tipoFluxo: 'receita',
          fluxo: fluxo,
          onSave: () {
            _loadReceitas();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receitas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showFormDialog(),
          ),
        ],
      ),
      body: FutureBuilder<List<FluxoCaixa>>(
        future: _receitasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma receita encontrada.'));
          }

          final receitas = snapshot.data!;
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          // Ordena receitas por data (mais nova primeiro)
          receitas.sort((a, b) {
            if (a.dataVencimento == null) return 1;
            if (b.dataVencimento == null) return -1;
            return b.dataVencimento!.compareTo(a.dataVencimento!);
          });

          final groupedReceitas = _groupByMonth(receitas);
          final sortedMonthKeys = _getSortedMonthKeys(groupedReceitas);

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: sortedMonthKeys.length,
            itemBuilder: (context, index) {
              final monthKey = sortedMonthKeys[index];
              final monthReceitas = groupedReceitas[monthKey]!;
              final isExpanded = _expandedMonths.contains(monthKey);

              // Calcula o total do mês
              final totalMes = monthReceitas.fold<double>(
                0.0,
                (sum, r) => sum + (r.valor ?? 0.0),
              );

              // Label do mês
              String monthLabel;
              DateTime? monthDate;
              if (monthKey == 'sem-data') {
                monthLabel = 'Sem data';
              } else {
                final parts = monthKey.split('-');
                monthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                monthLabel = _getMonthYearLabel(monthDate);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho do mês
                  InkWell(
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
                        horizontal: 16,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.green[300] : Colors.green[600])!
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            color:
                                isDark ? Colors.green[300] : Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              monthLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark
                                        ? Colors.green[300]
                                        : Colors.green[600],
                              ),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(totalMes),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark
                                      ? Colors.green[300]
                                      : Colors.green[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.green[300]
                                      : Colors.green[600],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${monthReceitas.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Lista de receitas do mês
                  if (isExpanded)
                    ...monthReceitas.map((receita) {
                      final categoriaNome = _getCategoriaNome(
                        receita.idCategoria,
                      );
                      final dataFormatada =
                          receita.dataVencimento != null
                              ? '${receita.dataVencimento!.day.toString().padLeft(2, '0')}/${receita.dataVencimento!.month.toString().padLeft(2, '0')}'
                              : '';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _showFormDialog(fluxo: receita),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Ícone circular
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? Colors.green[300]
                                            : Colors.green[600])!
                                        .withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.attach_money,
                                    color:
                                        isDark
                                            ? Colors.green[300]
                                            : Colors.green[600],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Informações principais
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        receita.descricao ?? 'Sem descrição',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (categoriaNome.isNotEmpty) ...[
                                            Text(
                                              categoriaNome,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              receita.confirmado == true
                                                  ? 'Confirmado'
                                                  : 'Pendente',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    receita.confirmado == true
                                                        ? (isDark
                                                            ? Colors.green[300]
                                                            : Colors.green[600])
                                                        : (isDark
                                                            ? Colors.orange[300]
                                                            : Colors
                                                                .orange[600]),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Valor e data
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(receita.valor),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDark
                                                ? Colors.green[300]
                                                : Colors.green[600],
                                      ),
                                    ),
                                    if (dataFormatada.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        dataFormatada,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(width: 8),
                                // Botões de ação
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: Colors.grey[600],
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      _showFormDialog(fluxo: receita);
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text(
                                                'Confirmar exclusão',
                                              ),
                                              content: Text(
                                                'Deseja realmente excluir "${receita.descricao}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        context,
                                                      ).pop(false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        context,
                                                      ).pop(true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  child: const Text('Excluir'),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (confirm == true) {
                                        await _apiService.deleteFluxo(
                                          receita.id!,
                                          receita.idRef ?? 0,
                                        );
                                        _loadReceitas();
                                      }
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                size: 20,
                                                color:
                                                    isDark
                                                        ? Colors.blue[300]
                                                        : Colors.blue[600],
                                              ),
                                              const SizedBox(width: 12),
                                              const Text('Editar'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color:
                                                    isDark
                                                        ? Colors.red[300]
                                                        : Colors.red[600],
                                              ),
                                              const SizedBox(width: 12),
                                              const Text('Excluir'),
                                            ],
                                          ),
                                        ),
                                      ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
