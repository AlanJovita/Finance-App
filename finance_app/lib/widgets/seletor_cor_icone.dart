import 'package:flutter/material.dart';

import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';

/// Paleta fixa de cores, em uma faixa de bolinhas.
class SeletorCor extends StatelessWidget {
  final String? selecionada;
  final ValueChanged<String> onSelecionar;

  const SeletorCor({
    super.key,
    required this.selecionada,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cor',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final cor in CategoriaVisuais.paleta)
              _Bolinha(
                cor: CategoriaVisuais.cor(cor.hex),
                rotulo: cor.nome,
                selecionada: cor.hex == selecionada,
                onTap: () => onSelecionar(cor.hex),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bolinha extends StatelessWidget {
  final Color cor;
  final String rotulo;
  final bool selecionada;
  final VoidCallback onTap;

  const _Bolinha({
    required this.cor,
    required this.rotulo,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: rotulo,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            border:
                selecionada
                    ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2,
                    )
                    : null,
          ),
          child:
              selecionada
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
        ),
      ),
    );
  }
}

/// Faixa com os ícones sugeridos e um atalho para o catálogo completo.
///
/// Os sugeridos ficam à mão porque cobrem a maioria dos cadastros; o resto do
/// catálogo sai do caminho, atrás do botão de busca, para o modal não crescer.
class SeletorIcone extends StatelessWidget {
  final String? selecionado;
  final Color cor;
  final ValueChanged<String?> onSelecionar;

  const SeletorIcone({
    super.key,
    required this.selecionado,
    required this.cor,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // O escolhido entra na faixa mesmo quando não é um dos sugeridos, senão o
    // usuário perde de vista o que acabou de selecionar no catálogo.
    final nomes = [
      ...CategoriaVisuais.iconesSugeridos,
      if (selecionado != null &&
          selecionado!.isNotEmpty &&
          !CategoriaVisuais.iconesSugeridos.contains(selecionado))
        selecionado!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ícone',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton.icon(
              onPressed: () => _abrirCatalogo(context),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Ver todos'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final nome in nomes)
              _ChipIcone(
                icone: CategoriaVisuais.icone(nome),
                cor: cor,
                selecionado: nome == selecionado,
                // Tocar no já selecionado limpa: o ícone é opcional e sem isso
                // não haveria como voltar ao genérico.
                onTap: () => onSelecionar(nome == selecionado ? null : nome),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _abrirCatalogo(BuildContext context) async {
    final escolhido = await showDialog<String>(
      context: context,
      builder: (_) => _CatalogoIconesDialog(selecionado: selecionado, cor: cor),
    );
    if (escolhido != null) onSelecionar(escolhido);
  }
}

class _ChipIcone extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipIcone({
    required this.icone,
    required this.cor,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cor.withValues(alpha: selecionado ? 1.0 : 0.15),
        ),
        child: Icon(
          icone,
          size: 19,
          color: selecionado ? Colors.white : cor,
        ),
      ),
    );
  }
}

/// Catálogo completo com busca por nome em português.
class _CatalogoIconesDialog extends StatefulWidget {
  final String? selecionado;
  final Color cor;

  const _CatalogoIconesDialog({required this.selecionado, required this.cor});

  @override
  State<_CatalogoIconesDialog> createState() => _CatalogoIconesDialogState();
}

class _CatalogoIconesDialogState extends State<_CatalogoIconesDialog> {
  final _buscaController = TextEditingController();
  late List<String> _resultados = CategoriaVisuais.buscarIcones('');

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _buscar(String termo) {
    setState(() => _resultados = CategoriaVisuais.buscarIcones(termo));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Escolher ícone'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: 360,
        height: 380,
        child: Column(
          children: [
            TextField(
              controller: _buscaController,
              autofocus: true,
              onChanged: _buscar,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Buscar (ex.: alimentação, carro, imposto)',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child:
                  _resultados.isEmpty
                      ? Center(
                        child: Text(
                          'Nenhum ícone encontrado',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                      : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: _resultados.length,
                        itemBuilder: (context, i) {
                          final nome = _resultados[i];
                          final entrada = CategoriaVisuais.catalogo[nome]!;
                          final selecionado = nome == widget.selecionado;

                          return InkWell(
                            onTap: () => Navigator.of(context).pop(nome),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.cor.withValues(
                                      alpha: selecionado ? 1.0 : 0.15,
                                    ),
                                  ),
                                  child: Icon(
                                    entrada.icone,
                                    size: 21,
                                    color:
                                        selecionado
                                            ? Colors.white
                                            : widget.cor,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  entrada.rotulo,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
