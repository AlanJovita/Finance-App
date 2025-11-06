import 'package:finance_app/widgets/fluxo_form_dialog.dart';
import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
import '../services/api_service.dart';

class DespesasPage extends StatefulWidget {
  const DespesasPage({super.key});

  @override
  State<DespesasPage> createState() => _DespesasPageState();
}

class _DespesasPageState extends State<DespesasPage> {
  late Future<List<FluxoCaixa>> _despesasFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadDespesas();
  }

  void _loadDespesas() {
    setState(() {
      _despesasFuture = _apiService.listFluxos("tipo_fluxo='despesa'");
    });
  }

  void _showFormDialog({FluxoCaixa? fluxo}) {
    showDialog(
      context: context,
      builder: (context) {
        return FluxoFormDialog(
          tipoFluxo: 'despesa',
          fluxo: fluxo,
          onSave: () {
            _loadDespesas();
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
        title: const Text('Despesas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showFormDialog(),
          ),
        ],
      ),
      body: FutureBuilder<List<FluxoCaixa>>(
        future: _despesasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma despesa encontrada.'));
          }

          final despesas = snapshot.data!;
          return ListView.builder(
            itemCount: despesas.length,
            itemBuilder: (context, index) {
              final despesa = despesas[index];
              return ListTile(
                title: Text(despesa.descricao),
                subtitle: Text('R\$ ${despesa.valor.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showFormDialog(fluxo: despesa),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        // Lógica de exclusão
                        await _apiService.deleteFluxo(
                          despesa.id!,
                          despesa.idRef ?? 0,
                        );
                        _loadDespesas();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
