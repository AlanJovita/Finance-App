import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';

class FluxoFormDialog extends StatefulWidget {
  final String tipoFluxo;
  final FluxoCaixa? fluxo;
  final VoidCallback onSave;

  const FluxoFormDialog({
    super.key,
    required this.tipoFluxo,
    this.fluxo,
    required this.onSave,
  });

  @override
  State<FluxoFormDialog> createState() => _FluxoFormDialogState();
}

class _FluxoFormDialogState extends State<FluxoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _parcelasController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  DateTime? _dataVencimento;
  bool _confirmado = false;
  String _repeticao = '1'; // 1 = única vez
  int? _categoriaId = 0;
  List<dynamic> _categorias = [];
  int _numeroParcelas = 1;
  bool _valorEhParcela = true; // true = valor da parcela, false = valor total

  @override
  void initState() {
    super.initState();
    _loadCategorias();
    _dataVencimento = DateTime.now();

    if (widget.fluxo != null) {
      _descricaoController.text = widget.fluxo!.descricao ?? '';
      _valorController.text = widget.fluxo!.valor?.toString() ?? '';
      _categoriaId = widget.fluxo!.idCategoria ?? 0;
      _dataVencimento = widget.fluxo!.dataVencimento ?? DateTime.now();
      _confirmado = widget.fluxo!.confirmado ?? false;
      _repeticao = widget.fluxo!.repeticao ?? '1';
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _parcelasController.dispose();
    super.dispose();
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

  int _gerarIdRef() {
    final now = DateTime.now();
    final idLoja = GlobalState().firstIdLoja;
    return int.parse(
      '$idLoja${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}',
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      // Validação da descrição
      if (_descricaoController.text.trim().length < 3) {
        _showError('A descrição deve ter no mínimo 3 caracteres');
        return;
      }

      // Validação do valor
      final valorText = _valorController.text.replaceAll(',', '.');
      final valorBase = double.tryParse(valorText);

      if (valorBase == null) {
        _showError('Valor inválido. Use apenas números');
        return;
      }

      if (valorBase <= 0) {
        _showError('O valor deve ser maior que zero');
        return;
      }

      setState(() => _isLoading = true);

      final tipoFluxoValue = widget.tipoFluxo == 'receita' ? '1' : '2';

      try {
        // Se for edição simples
        if (widget.fluxo != null) {
          final fluxo = FluxoCaixa(
            id: widget.fluxo!.id,
            idLoja: GlobalState().firstIdLoja,
            idCategoria: _categoriaId ?? 0,
            descricao: _descricaoController.text,
            valor: valorBase,
            tipoFluxo: tipoFluxoValue,
            cancelado: false,
            confirmado: _confirmado,
            dataCriacao: DateTime.now(),
            dataVencimento: _dataVencimento ?? DateTime.now(),
            diaVencimento: (_dataVencimento ?? DateTime.now()).day,
            repeticao: _repeticao,
            idRef: widget.fluxo!.idRef,
          );
          await _apiService.updateFluxo(fluxo);
        } else {
          // Nova entrada
          if (_repeticao == '1') {
            // Única vez
            final fluxo = FluxoCaixa(
              id: 0,
              idLoja: GlobalState().firstIdLoja,
              idCategoria: _categoriaId ?? 0,
              descricao: _descricaoController.text,
              valor: valorBase,
              tipoFluxo: tipoFluxoValue,
              cancelado: false,
              confirmado: _confirmado,
              dataCriacao: DateTime.now(),
              dataVencimento: _dataVencimento ?? DateTime.now(),
              diaVencimento: (_dataVencimento ?? DateTime.now()).day,
              repeticao: _repeticao,
              idRef: 0,
            );
            await _apiService.createFluxo(fluxo);
          } else {
            // Parcelado
            final idRef = _gerarIdRef();
            final valorParcela =
                _valorEhParcela ? valorBase : valorBase / _numeroParcelas;

            for (int i = 0; i < _numeroParcelas; i++) {
              DateTime dataVencimentoParcela;

              switch (_repeticao) {
                case '2': // Diária
                  dataVencimentoParcela = (_dataVencimento ?? DateTime.now())
                      .add(Duration(days: i));
                  break;
                case '3': // Semanal
                  dataVencimentoParcela = (_dataVencimento ?? DateTime.now())
                      .add(Duration(days: i * 7));
                  break;
                case '4': // Mensal
                  final dataBase = _dataVencimento ?? DateTime.now();
                  dataVencimentoParcela = DateTime(
                    dataBase.year,
                    dataBase.month + i,
                    dataBase.day,
                  );
                  break;
                case '5': // Anual
                  final dataBase = _dataVencimento ?? DateTime.now();
                  dataVencimentoParcela = DateTime(
                    dataBase.year + i,
                    dataBase.month,
                    dataBase.day,
                  );
                  break;
                default:
                  dataVencimentoParcela = _dataVencimento ?? DateTime.now();
              }

              final descricaoComParcela =
                  '${_descricaoController.text} [${i + 1}/$_numeroParcelas]';

              final fluxo = FluxoCaixa(
                id: 0,
                idLoja: GlobalState().firstIdLoja,
                idCategoria: _categoriaId ?? 0,
                descricao: descricaoComParcela,
                valor: valorParcela,
                tipoFluxo: tipoFluxoValue,
                cancelado: false,
                confirmado: _confirmado,
                dataCriacao: DateTime.now(),
                dataVencimento: dataVencimentoParcela,
                diaVencimento: dataVencimentoParcela.day,
                repeticao: _repeticao,
                idRef: idRef,
              );
              await _apiService.createFluxo(fluxo);
            }
          }
        }

        widget.onSave();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataVencimento ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _dataVencimento) {
      setState(() {
        _dataVencimento = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.fluxo == null ? 'Nova' : 'Editar'} ${widget.tipoFluxo == 'receita' ? 'Receita' : 'Despesa'}',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                  helperText: 'Mínimo 3 caracteres',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  if (value.trim().length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valorController,
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                  helperText:
                      'Use vírgula ou ponto para decimais (maior que 0)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  final valorLimpo = value.replaceAll(',', '.');
                  final numero = double.tryParse(valorLimpo);
                  if (numero == null) {
                    return 'Valor inválido';
                  }
                  if (numero <= 0) {
                    return 'Deve ser maior que zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoriaId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('Sem categoria'),
                  ),
                  ..._categorias.map((cat) {
                    return DropdownMenuItem<int>(
                      value: cat.id,
                      child: Text(cat.nome ?? 'Sem nome'),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _categoriaId = value ?? 0;
                  });
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data de Vencimento'),
                subtitle: Text(
                  _dataVencimento != null
                      ? '${_dataVencimento!.day.toString().padLeft(2, '0')}/${_dataVencimento!.month.toString().padLeft(2, '0')}/${_dataVencimento!.year}'
                      : 'Selecione uma data',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selecionarData,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _repeticao,
                decoration: const InputDecoration(
                  labelText: 'Repetição',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('Única vez')),
                  DropdownMenuItem(value: '2', child: Text('Diária')),
                  DropdownMenuItem(value: '3', child: Text('Semanal')),
                  DropdownMenuItem(value: '4', child: Text('Mensal')),
                  DropdownMenuItem(value: '5', child: Text('Anual')),
                ],
                onChanged:
                    widget.fluxo != null
                        ? null
                        : (value) {
                          if (value != null) {
                            setState(() {
                              _repeticao = value;
                              if (value != '1') {
                                _numeroParcelas = 2;
                                _parcelasController.text = '2';
                              } else {
                                _parcelasController.clear();
                              }
                            });
                          }
                        },
              ),
              const SizedBox(height: 12),
              if (_repeticao != '1' && widget.fluxo == null) ...[
                TextFormField(
                  controller: _parcelasController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Parcelas',
                    border: OutlineInputBorder(),
                    helperText: 'Mínimo 2 parcelas',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _numeroParcelas = int.tryParse(value) ?? 1;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num < 2) {
                      return 'Mínimo 2 parcelas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Valor é da parcela'),
                  value: true,
                  groupValue: _valorEhParcela,
                  onChanged: (value) {
                    setState(() {
                      _valorEhParcela = value ?? true;
                    });
                  },
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Valor total a dividir'),
                  value: false,
                  groupValue: _valorEhParcela,
                  onChanged: (value) {
                    setState(() {
                      _valorEhParcela = value ?? true;
                    });
                  },
                ),
                if (!_valorEhParcela && _numeroParcelas > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Valor por parcela: R\$ ${(double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0) / _numeroParcelas}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Confirmado'),
                value: _confirmado,
                onChanged: (value) {
                  setState(() {
                    _confirmado = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}
