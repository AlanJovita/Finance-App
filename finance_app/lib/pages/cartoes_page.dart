import 'package:flutter/material.dart';

import '../models/cartao.dart';
import '../services/api_service.dart';
import '../services/cartoes_cache.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/bancos.dart';
import '../utils/bandeiras.dart';
import '../utils/currency_formatter.dart';
import '../utils/meses.dart';
import '../utils/responsive_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/cartao_form_dialog.dart';
import '../widgets/logo_bandeira.dart';
import '../widgets/shimmer_widgets.dart';
import 'cartao_movimentos_page.dart';

/// Cartões de crédito da loja, com saldo devedor e limite disponível.
///
/// Gêmea da [ContasPage], com uma diferença que não é de layout: **não há
/// navegador de mês**. Saldo de conta bancária é um acumulado até uma data, e por
/// isso a página de Contas escolhe o mês; dívida de cartão é um número de
/// *agora*, e um "saldo devedor de março" não significa nada para quem quer saber
/// quanto deve. Quem navega por fatura é a [CartaoMovimentosPage].
///
/// Uma requisição por carga: o resumo de todos os cartões vem de um agrupamento
/// do lado do servidor, não de uma consulta por cartão.
class CartoesPage extends StatefulWidget {
  const CartoesPage({super.key});

  @override
  State<CartoesPage> createState() => _CartoesPageState();
}

class _CartoesPageState extends State<CartoesPage> {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  List<ResumoCartao> _cartoes = const [];
  bool _carregando = true;
  Object? _erro;

  /// Cada carga leva um número e só a mais recente pode escrever no estado — o
  /// mesmo cuidado da [ContasPage] e da [FluxosPage].
  int _geracao = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  // ---------------------------------------------------------------- dados

  Future<void> _carregar() async {
    final geracao = ++_geracao;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final cartoes = await _apiService.getResumoCartoes();

      if (!mounted || geracao != _geracao) return;

      setState(() {
        _cartoes = cartoes;
        _carregando = false;
      });
    } catch (e, s) {
      await _logger.logError('CartoesPage._carregar', e, stackTrace: s);

      if (!mounted || geracao != _geracao) return;

      setState(() {
        _erro = e;
        _carregando = false;
      });
    }
  }

  double get _totalDevedor =>
      _cartoes.fold(0.0, (soma, c) => soma + c.saldoDevedor);

  double get _totalAtraso => _cartoes.fold(0.0, (soma, c) => soma + c.emAtraso);

  double get _totalFaturaAtual =>
      _cartoes.fold(0.0, (soma, c) => soma + c.faturaAtual);

  double get _totalFuturas =>
      _cartoes.fold(0.0, (soma, c) => soma + c.parcelasFuturas);

  /// Soma só os limites informados, para o disponível total não ficar menor que a
  /// soma dos disponíveis de quem declarou limite.
  double get _totalLimite => _cartoes
      .where((c) => c.limite > 0)
      .fold(0.0, (soma, c) => soma + c.limite);

  // ---------------------------------------------------------------- ações

  Future<void> _novoCartao() async {
    final gravou = await showDialog<bool>(
      context: context,
      builder: (_) => const CartaoFormDialog(),
    );
    if (gravou == true) _carregar();
  }

  Future<void> _editar(ResumoCartao resumo) async {
    // O formulário trabalha com `Cartao`; o que a página tem é o resumo. A
    // resposta do resumo já traz todos os campos do cadastro, então converter
    // aqui evita uma consulta só para reabrir o que já está na tela.
    final gravou = await showDialog<bool>(
      context: context,
      builder:
          (_) => CartaoFormDialog(
            cartao: resumo.paraCartao(GlobalState().firstIdLoja),
          ),
    );
    if (gravou == true) _carregar();
  }

  Future<void> _abrirMovimentos(ResumoCartao resumo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CartaoMovimentosPage(
              cartao: resumo.paraCartao(GlobalState().firstIdLoja),
            ),
      ),
    );

    // Lançar, fechar ou pagar uma fatura muda o saldo devedor. Recarrega na
    // volta em vez de confiar no que estava na tela.
    if (mounted) _carregar();
  }

  /// Apaga o cartão.
  ///
  /// A API recusa quando há lançamento e devolve a contagem em vez de erro — é a
  /// recusa que vira a segunda pergunta, com "Arquivar" como saída preferida.
  /// Não existe "mover para outro cartão" como na conta bancária: cada cartão tem
  /// o seu ciclo de fechamento, e realocar as compras as jogaria em faturas que
  /// nunca existiram.
  Future<void> _apagar(ResumoCartao resumo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Apagar "${resumo.descricao}"?'),
            content: const Text(
              'O cadastro do cartão é removido. As despesas de fatura já '
              'lançadas no caixa continuam existindo — elas são dinheiro que '
              'saiu da conta.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.appColors.error,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Apagar'),
              ),
            ],
          ),
    );

    if (confirmado != true) return;

    try {
      final quantidade = await _apiService.deleteCartao(resumo.id);

      if (!mounted) return;

      if (quantidade != null) {
        await _apagarComLancamentos(resumo, quantidade);
        return;
      }

      CartoesCache().invalidar();
      _avisar('Cartão "${resumo.descricao}" apagado');
      _carregar();
    } catch (e, s) {
      await _logger.logError(
        'CartoesPage._apagar',
        e,
        stackTrace: s,
        additionalInfo: {'id': resumo.id},
      );
      if (mounted) _erroSnack('Não foi possível apagar o cartão: $e');
    }
  }

  /// A segunda pergunta, quando o cartão tem lançamento.
  ///
  /// "Arquivar" vem primeiro e é a ação destacada: é o caminho certo para parar
  /// de usar um cartão, e preserva o histórico. Apagar os lançamentos é a saída
  /// para o cartão criado por engano.
  Future<void> _apagarComLancamentos(ResumoCartao resumo, int quantidade) async {
    final quantos =
        '$quantidade ${quantidade == 1 ? 'lançamento' : 'lançamentos'}';

    final escolha = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('"${resumo.descricao}" tem $quantos'),
            content: const Text(
              'Arquivar tira o cartão do lançamento e mantém o saldo devedor e '
              'o histórico aqui.\n\n'
              'Apagar remove o cartão, os lançamentos e as faturas dele. As '
              'despesas de fatura já lançadas no caixa continuam existindo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.error,
                ),
                onPressed: () => Navigator.of(context).pop('apagar'),
                child: const Text('Apagar tudo'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('arquivar'),
                child: const Text('Arquivar'),
              ),
            ],
          ),
    );

    if (escolha == null) return;

    try {
      if (escolha == 'arquivar') {
        await _apiService.updateCartao(
          resumo.paraCartao(GlobalState().firstIdLoja).copyWith(ativado: false),
        );
      } else {
        await _apiService.deleteCartao(resumo.id, comMovimentos: true);
      }

      CartoesCache().invalidar();

      if (!mounted) return;

      _avisar(
        escolha == 'arquivar'
            ? 'Cartão "${resumo.descricao}" arquivado'
            : 'Cartão "${resumo.descricao}" apagado',
      );
      _carregar();
    } catch (e, s) {
      await _logger.logError(
        'CartoesPage._apagarComLancamentos',
        e,
        stackTrace: s,
        additionalInfo: {'id': resumo.id, 'escolha': escolha},
      );
      if (mounted) _erroSnack('Não foi possível concluir: $e');
    }
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _erroSnack(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: context.appColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões de Crédito')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _novoCartao,
        tooltip: 'Novo cartão',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(onRefresh: _carregar, child: _corpo()),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return SingleChildScrollView(
        padding: context.responsivePadding(),
        child: Column(
          children: [
            ShimmerWidgets.dashboardCardShimmer(context),
            SizedBox(height: context.responsiveSpacing()),
            ShimmerWidgets.listCaixasShimmer(context),
          ],
        ),
      );
    }

    if (_erro != null) {
      return _centralizado(
        icone: Icons.cloud_off,
        titulo: 'Não foi possível carregar os cartões',
        descricao: '$_erro',
        acao: FilledButton.icon(
          onPressed: _carregar,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
        ),
      );
    }

    if (_cartoes.isEmpty) {
      return _centralizado(
        icone: Icons.credit_card,
        titulo: 'Nenhum cartão cadastrado',
        descricao:
            'Cadastre os cartões de crédito da loja para controlar as compras '
            'por fatura. As compras do cartão não entram no caixa: no '
            'fechamento, a fatura vira uma despesa única nas suas Despesas — '
            'nada do que já existe muda.',
        acao: FilledButton.icon(
          onPressed: _novoCartao,
          icon: const Icon(Icons.add),
          label: const Text('Cadastrar cartão'),
        ),
      );
    }

    return ListView(
      padding: context.responsivePadding(),
      children: [
        _resumo(),
        const SizedBox(height: AppSpacing.lg),
        for (final cartao in _cartoes) _cartaoLinha(cartao),
        // Respiro para o FAB não cobrir o último cartão.
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _centralizado({
    required IconData icone,
    required String titulo,
    required String descricao,
    required Widget acao,
  }) {
    final theme = Theme.of(context);

    // Rola mesmo sem precisar: o RefreshIndicator só dispara dentro de um
    // scrollable, e puxar para recarregar tem de funcionar na tela vazia também.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Icon(
          icone,
          size: 56,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          descricao,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(child: acao),
      ],
    );
  }

  /// Saldo devedor total, com os baldes que dizem o que fazer com ele.
  ///
  /// O total sozinho não orienta: R$ 3.000 devidos são uma coisa se a maior parte
  /// é parcela de 2027, e outra se há fatura vencida. Os três recortes abaixo são
  /// disjuntos e somam o total.
  Widget _resumo() {
    final theme = Theme.of(context);
    final cores = context.appColors;

    final disponivel = _totalLimite > 0 ? _totalLimite - _totalDevedor : null;

    return Card(
      elevation: AppElevation.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo devedor total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              CurrencyFormatter.format(_totalDevedor),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                // Dívida de cartão não é "saldo negativo": zero é bom e qualquer
                // valor é compromisso. Por isso o número não fica vermelho por
                // ser positivo — só o que está em atraso recebe a cor de erro.
                color: _totalAtraso > 0 ? cores.error : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                if (_totalAtraso > 0)
                  _parcela('Em atraso', _totalAtraso, cores.error),
                _parcela('Fatura atual', _totalFaturaAtual, cores.info),
                if (_totalFuturas > 0)
                  _parcela(
                    'Parcelas futuras',
                    _totalFuturas,
                    theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            if (disponivel != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.credit_score, size: 14, color: cores.success),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Limite disponível: '
                      '${CurrencyFormatter.format(disponivel)} '
                      'de ${CurrencyFormatter.format(_totalLimite)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _parcela(String rotulo, double valor, Color cor) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rotulo,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          CurrencyFormatter.format(valor),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _cartaoLinha(ResumoCartao cartao) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final nomeBanco = Bancos.nome(cartao.banco);
    final nomeBandeira = Bandeiras.nome(cartao.bandeira);
    final arquivado = !cartao.ativado;
    final uso = cartao.usoDoLimite;

    final trilha = [
      if (nomeBandeira.isNotEmpty) nomeBandeira,
      if (nomeBanco.isNotEmpty) nomeBanco,
      'fecha dia ${cartao.diaFechamento}',
    ].join(' · ');

    return Card(
      elevation: arquivado ? AppElevation.none : AppElevation.card,
      color: arquivado ? theme.colorScheme.surfaceContainerHighest : null,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _abrirMovimentos(cartao),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Opacity(
                    opacity: arquivado ? 0.6 : 1,
                    child: LogoBandeira(chave: cartao.bandeira, largura: 44),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                cartao.descricao,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (arquivado) ...[
                              const SizedBox(width: AppSpacing.sm),
                              _chip(
                                'Arquivado',
                                theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trilha,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(cartao.saldoDevedor),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cartao.emAtraso > 0 ? cores.error : null,
                        ),
                      ),
                      if (cartao.limiteDisponivel != null)
                        Text(
                          '${CurrencyFormatter.format(cartao.limiteDisponivel)} livre',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                cartao.limiteDisponivel! < 0
                                    ? cores.error
                                    : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opções do cartão',
                    position: PopupMenuPosition.under,
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (opcao) {
                      if (opcao == 'lancamentos') _abrirMovimentos(cartao);
                      if (opcao == 'editar') _editar(cartao);
                      if (opcao == 'apagar') _apagar(cartao);
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: 'lancamentos',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long, size: 18),
                                SizedBox(width: AppSpacing.sm),
                                Text('Lançamentos'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: AppSpacing.sm),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'apagar',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18),
                                SizedBox(width: AppSpacing.sm),
                                Text('Apagar'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              // A barra de uso do limite só aparece com limite informado: sem
              // ele não há denominador, e uma barra vazia sugeriria limite zero.
              if (uso != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: uso,
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    // Acima de 90% do limite a barra avisa: é o ponto em que a
                    // próxima compra pode ser recusada.
                    color: uso >= 0.9 ? cores.error : cores.info,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _linhaFatura(cartao),
            ],
          ),
        ),
      ),
    );
  }

  /// A fatura em foco do cartão: valor, vencimento e o que está em atraso.
  Widget _linhaFatura(ResumoCartao cartao) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final competencia = cartao.competenciaAtual;
    final vencimento = cartao.vencimentoAtual;

    final partes = <String>[
      if (competencia != null)
        'Fatura de ${rotuloMes(competencia).toLowerCase()}: '
            '${CurrencyFormatter.format(cartao.faturaAtual)}',
      if (vencimento != null)
        'vence ${vencimento.day.toString().padLeft(2, '0')}/'
            '${vencimento.month.toString().padLeft(2, '0')}',
    ];

    return Row(
      children: [
        Icon(
          Icons.receipt_long,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            partes.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (cartao.emAtraso > 0)
          _chip(
            '${CurrencyFormatter.format(cartao.emAtraso)} em atraso',
            cores.error,
          ),
      ],
    );
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        texto,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: cor, fontSize: 10),
      ),
    );
  }
}
