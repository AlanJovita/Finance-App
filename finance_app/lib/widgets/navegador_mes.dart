/// O seletor de mês das telas que falam de um mês por vez.
///
/// Nasceu dentro da `FluxosPage` e saiu para cá quando a página de Categorias
/// passou a precisar do mesmo controle. **Não é um extract gratuito:** o rótulo
/// do meio não é texto, é um menu com os meses em que a loja tem lançamento, e
/// uma segunda implementação dele ia divergir em duas coisas que não se leem no
/// desenho — a largura fixa do rótulo e o item sentinela do menu vazio (ver
/// abaixo).
library;

import 'package:flutter/material.dart';

import '../models/resumo_fluxo.dart';
import '../utils/app_tokens.dart';
import '../utils/meses.dart';

/// Setas de mês anterior/próximo com um atalho de meses no meio.
class NavegadorMes extends StatelessWidget {
  const NavegadorMes({
    super.key,
    required this.mes,
    required this.onMudarMes,
    this.meses = const [],
    this.larguraRotulo = 150,
  });

  /// O mês em foco. Só ano e mês importam; o dia é ignorado.
  final DateTime mes;

  /// Recebe o mês escolhido, já normalizado no dia 1.
  final ValueChanged<DateTime> onMudarMes;

  /// Os meses que têm movimento, para o atalho do rótulo. Vazio deixa o menu
  /// com o "Mês atual" e mais nada — é o caso de quem abre a tela numa loja
  /// sem lançamento nenhum.
  final List<ResumoMes> meses;

  /// Largura reservada ao rótulo. **Fixa de propósito**: sem ela a seta da
  /// direita dança de lugar conforme o nome do mês encolhe ou cresce
  /// ("Maio/2026" × "Setembro/2026"). A barra compacta passa um valor menor
  /// porque ali o navegador divide a linha com a busca e os filtros.
  final double larguraRotulo;

  static String _chave(DateTime mes) => '${mes.year}-${mes.month}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agora = DateTime.now();
    final noMesAtual = mes.year == agora.year && mes.month == agora.month;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mês anterior',
          visualDensity: VisualDensity.compact,
          onPressed: () => onMudarMes(DateTime(mes.year, mes.month - 1)),
        ),
        // Largura fixa: sem ela o botão seguinte dança de lugar conforme o
        // nome do mês encolhe ou cresce.
        SizedBox(
          width: larguraRotulo,
          child: _buildAtalhoMeses(context, theme, noMesAtual),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo mês',
          visualDensity: VisualDensity.compact,
          onPressed: () => onMudarMes(DateTime(mes.year, mes.month + 1)),
        ),
      ],
    );
  }

  /// O rótulo do mês é também um menu: lista os meses em que a loja tem
  /// lançamento, para não obrigar a clicar na seta doze vezes até achar.
  Widget _buildAtalhoMeses(
    BuildContext context,
    ThemeData theme,
    bool noMesAtual,
  ) {
    final comLancamento = meses.where((m) => !m.semData).toList();

    return PopupMenuButton<String>(
      tooltip: 'Escolher mês',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (chave) {
        final partes = chave.split('-');
        onMudarMes(DateTime(int.parse(partes[0]), int.parse(partes[1])));
      },
      itemBuilder: (context) {
        final agora = DateTime.now();
        final itens = <PopupMenuEntry<String>>[
          if (!noMesAtual)
            PopupMenuItem(
              value: _chave(DateTime(agora.year, agora.month)),
              child: const Row(
                children: [
                  Icon(Icons.today, size: 16),
                  SizedBox(width: AppSpacing.sm),
                  Text('Mês atual'),
                ],
              ),
            ),
          if (!noMesAtual && comLancamento.isNotEmpty) const PopupMenuDivider(),
          for (final m in comLancamento)
            PopupMenuItem(
              value: m.chave,
              child: Row(
                children: [
                  Expanded(child: Text(rotuloMes(DateTime(m.ano!, m.mes!)))),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${m.quantidade}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ];

        // Loja sem nenhum lançamento, parada no mês atual: as duas listas acima
        // ficam vazias e o `showMenu` do Material quebra num assert se abrir
        // sem item nenhum.
        if (itens.isEmpty) {
          itens.add(
            PopupMenuItem(
              enabled: false,
              child: Text(
                'Nenhum mês com lançamento',
                style: theme.textTheme.bodySmall,
              ),
            ),
          );
        }

        return itens;
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                rotuloMes(mes),
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
