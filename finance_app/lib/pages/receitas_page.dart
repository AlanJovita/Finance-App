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

  @override
  void initState() {
    super.initState();
    _loadReceitas();
  }

  void _loadReceitas() {
    setState(() {
      _receitasFuture = _apiService.listFluxos("tipo_fluxo='receita'");
    });
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
          return ListView.builder(
            itemCount: receitas.length,
            itemBuilder: (context, index) {
              final receita = receitas[index];
              return ListTile(
                title: Text(receita.descricao),
                subtitle: Text('R\$ ${receita.valor.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showFormDialog(fluxo: receita),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await _apiService.deleteFluxo(
                          receita.id!,
                          receita.idRef ?? 0,
                        );
                        _loadReceitas();
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
