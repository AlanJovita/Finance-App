import 'package:flutter/material.dart';

import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';

/// Uma opção do [SeletorCategoria] — serve tanto para categoria quanto para
/// subcategoria, que têm as mesmas regras de exibição.
class ItemSelecionavel {
  final int id;
  final String descricao;
  final String? icone;
  final Color cor;
  final bool destaque;

  const ItemSelecionavel({
    required this.id,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.destaque,
  });
}

/// Card de seleção em círculos, com combobox de transbordo.
///
/// As três faixas de comportamento, por quantidade de itens:
///
/// * **0** — mensagem de vazio e o botão de criar piscando, que é a única ação
///   possível ali.
/// * **1 a 4** — só os círculos. Um combobox com no máximo 4 opções repetiria o
///   que já está à vista.
/// * **5 ou mais** — os 4 primeiros em destaque viram círculos e o combobox
///   lista todos, inclusive esses 4, para a seleção nunca depender de adivinhar
///   onde o item está.
class SeletorCategoria extends StatefulWidget {
  final String titulo;
  final String rotuloBotaoNovo;
  final String mensagemVazio;

  final List<ItemSelecionavel> itens;
  final int? selecionadoId;
  final ValueChanged<int?> onSelecionar;
  final VoidCallback onNovo;

  /// Acrescenta "Sem categoria" ao combobox e permite desmarcar um círculo
  /// tocando nele de novo. Categoria e subcategoria são opcionais no
  /// lançamento, então o padrão é `true`.
  final bool permiteNenhum;
  final String rotuloNenhum;

  const SeletorCategoria({
    super.key,
    required this.titulo,
    required this.rotuloBotaoNovo,
    required this.mensagemVazio,
    required this.itens,
    required this.selecionadoId,
    required this.onSelecionar,
    required this.onNovo,
    this.permiteNenhum = true,
    this.rotuloNenhum = 'Sem categoria',
  });

  /// Quantos círculos cabem na faixa.
  static const int maximoCirculos = 4;

  /// Identifica o pulso do botão de criar. `FadeTransition` sozinho não serve de
  /// alvo nos testes: o `MaterialApp` usa vários nas transições de rota.
  static const Key chavePiscar = ValueKey('seletor-categoria-piscar');

  @override
  State<SeletorCategoria> createState() => _SeletorCategoriaState();
}

class _SeletorCategoriaState extends State<SeletorCategoria>
    with SingleTickerProviderStateMixin {
  late final AnimationController _piscar;

  @override
  void initState() {
    super.initState();
    _piscar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _sincronizarPiscar();
  }

  @override
  void didUpdateWidget(SeletorCategoria oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sincronizarPiscar();
  }

  /// A animação só roda na lista vazia: deixá-la girando com o card preenchido
  /// custa um rebuild por frame enquanto o modal estiver aberto.
  void _sincronizarPiscar() {
    if (widget.itens.isEmpty) {
      if (!_piscar.isAnimating) _piscar.repeat(reverse: true);
    } else if (_piscar.isAnimating) {
      _piscar.stop();
      _piscar.value = 0;
    }
  }

  @override
  void dispose() {
    _piscar.dispose();
    super.dispose();
  }

  /// Os 4 do topo: destaque primeiro, preservando a ordem de cadastro dentro de
  /// cada grupo. A API já devolve assim; reordenar aqui mantém o widget correto
  /// com qualquer origem de dados (inclusive nos testes).
  List<ItemSelecionavel> get _circulos {
    final ordenados = [...widget.itens];
    ordenados.sort((a, b) {
      if (a.destaque == b.destaque) return 0;
      return a.destaque ? -1 : 1;
    });
    return ordenados.take(SeletorCategoria.maximoCirculos).toList();
  }

  bool get _mostraCombobox =>
      widget.itens.length > SeletorCategoria.maximoCirculos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCabecalho(theme),
          const SizedBox(height: AppSpacing.sm),
          if (widget.itens.isEmpty)
            _buildVazio(theme)
          else ...[
            _buildCirculos(),
            if (_mostraCombobox) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildCombobox(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCabecalho(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            widget.titulo,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildBotaoNovo(theme),
      ],
    );
  }

  Widget _buildBotaoNovo(ThemeData theme) {
    final botao = TextButton.icon(
      onPressed: widget.onNovo,
      icon: const Icon(Icons.add, size: 16),
      label: Text(widget.rotuloBotaoNovo),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: theme.textTheme.labelMedium,
      ),
    );

    if (widget.itens.isNotEmpty) return botao;

    // Sem nada cadastrado, criar é a única saída: o pulso chama o olho para lá.
    return FadeTransition(
      key: SeletorCategoria.chavePiscar,
      opacity: Tween<double>(begin: 1.0, end: 0.35).animate(
        CurvedAnimation(parent: _piscar, curve: Curves.easeInOut),
      ),
      child: botao,
    );
  }

  Widget _buildVazio(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        widget.mensagemVazio,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildCirculos() {
    final circulos = _circulos;

    return Row(
      children: [
        for (final item in circulos)
          Expanded(
            child: _Circulo(
              item: item,
              selecionado: item.id == widget.selecionadoId,
              onTap: () {
                final jaSelecionado = item.id == widget.selecionadoId;
                if (jaSelecionado && !widget.permiteNenhum) return;
                widget.onSelecionar(jaSelecionado ? null : item.id);
              },
            ),
          ),
        // Mantém os círculos alinhados à esquerda quando são menos de 4, em vez
        // de esticá-los para ocupar a linha inteira.
        for (var i = circulos.length; i < SeletorCategoria.maximoCirculos; i++)
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  Widget _buildCombobox() {
    final ids = widget.itens.map((i) => i.id).toSet();
    final valor = ids.contains(widget.selecionadoId) ? widget.selecionadoId : 0;

    return DropdownButtonFormField<int>(
      value: valor,
      isExpanded: true,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      items: [
        if (widget.permiteNenhum)
          DropdownMenuItem(value: 0, child: Text(widget.rotuloNenhum)),
        for (final item in widget.itens)
          DropdownMenuItem(
            value: item.id,
            child: Row(
              children: [
                Icon(
                  CategoriaVisuais.icone(item.icone),
                  size: 16,
                  color: item.cor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.descricao,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (v) => widget.onSelecionar(v == 0 ? null : v),
    );
  }
}

/// Ícone em círculo colorido com o nome embaixo.
class _Circulo extends StatelessWidget {
  final ItemSelecionavel item;
  final bool selecionado;
  final VoidCallback onTap;

  const _Circulo({
    required this.item,
    required this.selecionado,
    required this.onTap,
  });

  static const double _diametro = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _diametro,
              height: _diametro,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.cor.withValues(alpha: selecionado ? 1.0 : 0.18),
                border:
                    selecionado
                        ? Border.all(color: item.cor, width: 2)
                        : null,
              ),
              child: Icon(
                CategoriaVisuais.icone(item.icone),
                size: 22,
                // No estado selecionado o círculo é sólido: o ícone precisa
                // virar branco para não sumir dentro da própria cor.
                color: selecionado ? Colors.white : item.cor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.descricao,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                height: 1.1,
                fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
                color:
                    selecionado
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
