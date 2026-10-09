import 'package:flutter/material.dart';

import '../utils/app_tokens.dart';
import '../utils/bandeiras.dart';
import 'logo_bandeira.dart';

/// Escolha da bandeira do cartão, em linha.
///
/// Diferente do [SeletorBanco], que abre diálogo de busca: o catálogo de bancos
/// tem dezenas de entradas e não cabe num formulário; o de bandeiras tem sete, e
/// sete selos passam numa faixa rolável sem empurrar nada. Um diálogo aqui seria
/// um toque extra para uma lista que cabe inteira na tela.
///
/// Toque no selo já marcado desmarca: bandeira é opcional, e o lojista que
/// escolheu errado não deveria precisar de um botão separado para limpar.
class SeletorBandeira extends StatelessWidget {
  /// Chave do catálogo, ou `null` para "nenhuma bandeira".
  final String? selecionado;

  final ValueChanged<String?> onSelecionar;

  const SeletorBandeira({
    super.key,
    required this.selecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chaves = Bandeiras.buscar('');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Bandeira',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                Bandeiras.nome(selecionado),
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Sete selos cabem num tablet e passam num celular; rolar na
          // horizontal é melhor que embrulhar em duas linhas, que faria o
          // formulário mudar de altura conforme a largura da tela.
          child: Row(
            children: [
              for (final chave in chaves) ...[
                _selo(context, chave),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _selo(BuildContext context, String chave) {
    final theme = Theme.of(context);
    final marcado = chave == selecionado;

    return Tooltip(
      message: Bandeiras.nome(chave),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        // Toque no já marcado desmarca.
        onTap: () => onSelecionar(marcado ? null : chave),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: marcado ? theme.colorScheme.primary : theme.dividerColor,
              width: marcado ? 2 : 1,
            ),
          ),
          child: LogoBandeira(chave: chave, largura: 44),
        ),
      ),
    );
  }
}
