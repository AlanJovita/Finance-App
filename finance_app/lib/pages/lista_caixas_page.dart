import 'package:finance_app/pages/caixa_page.dart';
import 'package:flutter/material.dart';
import '../models/caixa.dart';
import '../services/api_service.dart';

class ListaCaixasPage extends StatefulWidget {
  const ListaCaixasPage({super.key});

  @override
  State<ListaCaixasPage> createState() => _ListaCaixasPageState();
}

class _ListaCaixasPageState extends State<ListaCaixasPage> {
  late Future<List<Caixa>> _caixasFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCaixas();
  }

  void _loadCaixas() {
    // A API de exemplo não tem um endpoint para listar caixas,
    // então vamos simular com o endpoint getCaixa e criar uma lista.
    // Em um cenário real, você usaria algo como /caixa/list/{id_loja}
    setState(() {
      _caixasFuture = _apiService.getCaixa().then((caixa) => [caixa]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Caixas')),
      body: FutureBuilder<List<Caixa>>(
        future: _caixasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum caixa encontrado.'));
          }

          final caixas = snapshot.data!;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Data Abertura')),
                DataColumn(label: Text('Saldo')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Ações')),
              ],
              rows:
                  caixas.map((caixa) {
                    return DataRow(
                      cells: [
                        DataCell(Text(caixa.idCaixa?.toString() ?? 'N/A')),
                        DataCell(
                          Text(
                            caixa.dataAbertura?.toLocal().toString() ?? 'N/A',
                          ),
                        ),
                        DataCell(
                          Text(
                            'R\$ ${caixa.saldo?.toStringAsFixed(2) ?? '0.00'}',
                          ),
                        ),
                        DataCell(Text(caixa.statusCaixa?.toString() ?? 'N/A')),
                        DataCell(
                          ElevatedButton(
                            child: const Text('Abrir Caixa'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CaixaPage(caixa: caixa),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          );
        },
      ),
    );
  }
}
