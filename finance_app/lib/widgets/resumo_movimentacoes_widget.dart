import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/fluxo_caixa.dart';
import '../models/resumo_painel.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/currency_formatter.dart';
import '../utils/meses.dart';
import '../utils/situacao_fluxo.dart';
import 'charts/categorias_pie_chart.dart';
import 'charts/fluxo_acumulado_chart.dart';
import 'icone_categoria.dart';

/// O bloco de receitas e despesas do painel: saldos, as duas curvas do mês com
/// os últimos lançamentos, e as duas pizzas por categoria.
///
/// **Somente leitura, de propósito.** Editar, dar baixa e excluir continuam nas
/// telas de Receitas e Despesas — e é para lá que cada linha e cada "ver todas"
/// levam. Um painel que também edita duplicaria o `FluxoFormDialog`, o
/// `PagamentoDialog` e a regra de parcelamento que mora neles, e a primeira
/// divergência entre as duas cópias apareceria como "a baixa pelo painel não
/// replica a parcela".
///
/// Tudo vem de [ResumoPainel], que é **uma** requisição: o bloco não dispara
/// consulta nenhuma por conta própria.
class ResumoMovimentacoesWidget extends StatelessWidget {
  final ResumoPainel painel;

  /// Nome, cor e ícone por id. Quem carrega é a tela, que também usa o mapa nas
  /// listas — resolver por item seria uma busca por linha a cada rebuild.
  final Map<int, Categoria> categorias;

  /// Injetável para o teste fixar a situação dos lançamentos e o corte do
  /// realizado nos gráficos.
  final DateTime? hoje;

  const ResumoMovimentacoesWidget({
    super.key,
    required this.painel,
    required this.categorias,
    this.hoje,
  });

  @override
  Widget build(BuildContext context) {
    final cores = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalhoSecao(context),
        const SizedBox(height: AppSpacing.md),
        _cardSaldos(context),
        const SizedBox(height: AppSpacing.lg),
        _cardNatureza(
          context,
          titulo: 'Entradas de ${_nomeMes()}',
          ehReceita: true,
          itens: painel.ultimasReceitas,
          rota: '/receitas',
          cor: cores.success,
        ),
        const SizedBox(height: AppSpacing.lg),
        _cardNatureza(
          context,
          titulo: 'Saídas de ${_nomeMes()}',
          ehReceita: false,
          itens: painel.ultimasDespesas,
          rota: '/despesas',
          cor: cores.error,
        ),
        const SizedBox(height: AppSpacing.lg),
        _cardPizza(
          context,
          titulo: 'Receitas por categoria',
          grupos: painel.categoriasReceita,
        ),
        const SizedBox(height: AppSpacing.lg),
        _cardPizza(
          context,
          titulo: 'Despesas por categoria',
          grupos: painel.categoriasDespesa,
        ),
      ],
    );
  }

  /// "Outubro 2026" a partir do mês que o **servidor** resolveu — ver
  /// [ResumoPainel.mes].
  String _nomeMes() => nomesMeses[painel.inicio.month - 1];

  String _rotuloMesCompleto() => rotuloMes(painel.inicio);

  Widget _cabecalhoSecao(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.swap_vert,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Movimentações',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _rotuloMesCompleto(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- saldos

  /// Saldo do mês em cima, o que está em aberto embaixo.
  ///
  /// Os dois blocos respondem perguntas diferentes e por isso estão separados
  /// por um divisor: o saldo é **do mês**, e atraso\pendente são **de agora**,
  /// sem recorte de mês (um boleto de agosto que ninguém pagou continua em
  /// atraso em outubro). Somá-los na mesma linha sugeriria que fecham entre si.
  Widget _cardSaldos(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _saldo(
                    context,
                    'Saldo confirmado',
                    painel.resumo.saldoRealizado,
                    destaque: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _saldo(
                    context,
                    'Saldo projetado',
                    painel.resumo.saldoPrevisto,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: _emAberto(
                    context,
                    rotulo: 'Em atraso',
                    icone: Icons.error_outline,
                    cor: cores.error,
                    totais: painel.atraso,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _emAberto(
                    context,
                    rotulo: 'Pendentes',
                    icone: Icons.schedule,
                    cor: cores.warning,
                    totais: painel.pendente,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Atraso e pendências somam tudo que está em aberto, de qualquer mês.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saldo negativo é vermelho e positivo é verde — o sinal é a informação, e o
  /// `-` sozinho passa batido num número de sete dígitos.
  Widget _saldo(
    BuildContext context,
    String rotulo,
    double valor, {
    bool destaque = false,
  }) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final cor = valor < 0 ? cores.error : cores.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.format(valor),
            maxLines: 1,
            style: (destaque
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleMedium)
                ?.copyWith(color: cor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Receber e pagar de uma situação, lado a lado.
  ///
  /// Os dois juntos porque "R$ 3.000 em atraso" sem dizer de qual lado não
  /// decide nada: a receber é cobrança, a pagar é dívida.
  Widget _emAberto(
    BuildContext context, {
    required String rotulo,
    required IconData icone,
    required Color cor,
    required TotaisSituacao totais,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Ícone junto do rótulo: a cor sozinha não pode ser o que
            // distingue atraso de pendência.
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                rotulo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _linhaEmAberto(theme, 'A receber', totais.receber, totais.qtdReceber),
        const SizedBox(height: AppSpacing.xs),
        _linhaEmAberto(theme, 'A pagar', totais.pagar, totais.qtdPagar),
      ],
    );
  }

  Widget _linhaEmAberto(
    ThemeData theme,
    String rotulo,
    double valor,
    int quantidade,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.format(valor),
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (quantidade > 0)
          Text(
            quantidade == 1 ? '1 lançamento' : '$quantidade lançamentos',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------- gráfico + últimas

  Widget _cardNatureza(
    BuildContext context, {
    required String titulo,
    required bool ehReceita,
    required List<FluxoCaixa> itens,
    required String rota,
    required Color cor,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FluxoAcumuladoChart(
              diario: painel.diario,
              inicio: painel.inicio,
              fim: painel.fim,
              ehReceita: ehReceita,
              hoje: hoje,
            ),
            if (itens.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Últimos lançamentos',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, rota),
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final fluxo in itens)
                _LinhaMovimento(
                  fluxo: fluxo,
                  categoria: categorias[fluxo.idCategoria ?? 0],
                  cor: cor,
                  hoje: hoje,
                  onTap: () => Navigator.pushNamed(context, rota),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- pizza

  Widget _cardPizza(
    BuildContext context, {
    required String titulo,
    required List<TotalCategoria> grupos,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CategoriasPieChart(grupos: grupos, categorias: categorias),
          ],
        ),
      ),
    );
  }
}

/// Uma linha da lista de últimos lançamentos.
///
/// Mais enxuta que o [CardFluxo] da tela de Receitas porque aqui não há ação
/// nenhuma: sem botões, o conteúdo cabe numa linha e dez delas não empurram as
/// pizzas para fora da primeira rolagem.
class _LinhaMovimento extends StatelessWidget {
  final FluxoCaixa fluxo;
  final Categoria? categoria;

  /// Cor do valor: entrada é sucesso, saída é erro — a mesma convenção da tela
  /// da natureza.
  final Color cor;

  final DateTime? hoje;
  final VoidCallback onTap;

  const _LinhaMovimento({
    required this.fluxo,
    required this.categoria,
    required this.cor,
    required this.hoje,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final situacao = SituacaoFluxo.de(fluxo, hoje: hoje);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            IconeCategoria(
              iconeCategoria: categoria?.icone,
              corCategoria: CategoriaVisuais.cor(categoria?.cor),
              diametro: 28,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fluxo.descricao?.trim().isNotEmpty == true
                        ? fluxo.descricao!
                        : categoria?.descricao ?? 'Sem descrição',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      // Ícone + rótulo: a situação nunca é só a cor.
                      Icon(
                        situacao.icone,
                        size: 12,
                        color: situacao.cor(cores),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '${situacao.rotuloCurto}${_data()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              CurrencyFormatter.format(fluxo.valor),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// " · 10/10" — vazio quando o lançamento não tem vencimento, e aí a situação
  /// "Sem data" já diz o que há para dizer.
  String _data() {
    final vencimento = fluxo.dataVencimento;
    if (vencimento == null) return '';

    final dia = vencimento.day.toString().padLeft(2, '0');
    final mes = vencimento.month.toString().padLeft(2, '0');
    return ' · $dia/$mes';
  }
}
