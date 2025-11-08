import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
import '../services/api_service.dart';

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
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.fluxo != null) {
      _descricaoController.text = widget.fluxo!.descricao!;
      _valorController.text = widget.fluxo!.valor.toString();
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final fluxo = FluxoCaixa(
        id: widget.fluxo?.id,
        idLoja: 1, // Exemplo
        idCategoria: 1, // Exemplo
        descricao: _descricaoController.text,
        valor: double.tryParse(_valorController.text) ?? 0.0,
        tipoFluxo: widget.tipoFluxo,
      );

      try {
        if (widget.fluxo == null) {
          await _apiService.createFluxo(fluxo);
        } else {
          await _apiService.updateFluxo(fluxo);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.fluxo == null ? 'Nova' : 'Editar'} ${widget.tipoFluxo == 'receita' ? 'Receita' : 'Despesa'}',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descricaoController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              validator:
                  (value) =>
                      (value == null || value.isEmpty)
                          ? 'Campo obrigatório'
                          : null,
            ),
            TextFormField(
              controller: _valorController,
              decoration: const InputDecoration(labelText: 'Valor'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Campo obrigatório';
                if (double.tryParse(value) == null) return 'Valor inválido';
                return null;
              },
            ),
            // Adicionar campo de categoria aqui se necessário
          ],
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
