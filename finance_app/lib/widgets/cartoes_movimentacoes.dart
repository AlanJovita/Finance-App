/// Os cards de receitas e despesas do Resumo: saldos, as duas curvas do mês com
/// os últimos lançamentos, e as duas pizzas por categoria.
///
/// **Cada card é uma peça solta, não um bloco.** Eles vinham empilhados numa
/// `Column` única, com um cabeçalho "Movimentações" em cima. No Resumo quem os
/// posiciona agora é a `GradeCartoes`, que põe cada um na coluna mais curta — um
/// bloco monolítico de cinco cards viraria uma coluna de ~1800px ao lado de
/// colunas de 300px, que é exatamente o buraco que a grade existe para fechar.
/// O que o cabeçalho de seção dizia (o assunto e o mês) passou para o
/// [CartaoSaldos], que é o primeiro deles.
///
/// **Somente leitura, de propósito.** Editar, dar baixa e excluir continuam nas
/// telas de Receitas e Despesas — e é para lá que cada linha e cada "ver todas"
/// levam. Um painel que também edita duplicaria o `FluxoFormDialog`, o
/// `PagamentoDialog` e a regra de parcelamento que mora neles, e a primeira
/// divergência entre as duas cópias apareceria como "a baixa pelo painel não
/// replica a parcela".
///
/// Tudo vem de [ResumoPainel], que é **uma** requisição: nenhum destes cards
/// dispara consulta por conta própria.
library;

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

/// Casca comum dos cards daqui: mesma elevação, mesmo raio, mesmo respiro
/// interno. Existe para os cinco não divergirem um do outro com o tempo.
class _CascaCartao extends StatelessWidget {
  const _CascaCartao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: child,
      ),
    );
  }
}

/// Saldo do mês em cima, o que está em aberto embaixo.
///
/// Os dois blocos respondem perguntas diferentes e por isso estão separados
/// por um divisor: o saldo é **do mês**, e atraso\pendente são **de agora**,
/// sem recorte de mês (um boleto de agosto que ninguém pagou continua em
/// atraso em outubro). Somá-los na mesma linha sugeriria que fecham entre si.
///
/// É este card que carrega o título "Movimentações" e o mês: ele é o primeiro
/// da sequência, e com os cards soltos na grade não há mais cabeçalho de seção
/// onde pôr essa informação.
class CartaoSaldos extends StatelessWidget {
  const CartaoSaldos({super.key, required this.painel});

  final ResumoPainel painel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return _CascaCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecalho(context),
          const SizedBox(height: AppSpacing.lg),
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
    );
  }

  /// O que era o cabeçalho da seção "Movimentações": assunto e o mês que o
  /// **servidor** resolveu (ver [ResumoPainel.mes]).
  Widget _cabecalho(BuildContext context) {
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
            rotuloMes(painel.inicio),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

}

/// A curva acumulada de uma natureza no mês, com os últimos lançamentos dela
/// embaixo. Um card por natureza — entradas e saídas.
class CartaoNatureza extends StatelessWidget {
  const CartaoNatureza({
    super.key,
    required this.painel,
    required this.categorias,
    required this.ehReceita,
    this.hoje,
  });

  final ResumoPainel painel;

  /// Nome, cor e ícone por id. Quem carrega é a tela, que também usa o mapa nos
  /// outros cards — resolver por item seria uma busca por linha a cada rebuild.
  final Map<int, Categoria> categorias;

  final bool ehReceita;

  /// Injetável para o teste fixar a situação dos lançamentos e o corte do
  /// realizado no gráfico.
  final DateTime? hoje;

  List<FluxoCaixa> get _itens =>
      ehReceita ? painel.ultimasReceitas : painel.ultimasDespesas;

  String get _rota => ehReceita ? '/receitas' : '/despesas';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    // Entrada é sucesso, saída é erro — a mesma convenção da tela da natureza.
    final cor = ehReceita ? cores.success : cores.error;
    final nomeMes = nomesMeses[painel.inicio.month - 1];
    final itens = _itens;

    return _CascaCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ehReceita ? 'Entradas de $nomeMes' : 'Saídas de $nomeMes',
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
                  onPressed: () => Navigator.pushNamed(context, _rota),
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
                onTap: () => Navigator.pushNamed(context, _rota),
              ),
          ],
        ],
      ),
    );
  }
}

/// A pizza por categoria de uma natureza. Um card por natureza.
class CartaoCategorias extends StatelessWidget {
  const CartaoCategorias({
    super.key,
    required this.painel,
    required this.categorias,
    required this.ehReceita,
  });

  final ResumoPainel painel;
  final Map<int, Categoria> categorias;
  final bool ehReceita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CascaCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ehReceita ? 'Receitas por categoria' : 'Despesas por categoria',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CategoriasPieChart(
            grupos:
                ehReceita
                    ? painel.categoriasReceita
                    : painel.categoriasDespesa,
            categorias: categorias,
          ),
        ],
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
