import 'package:flutter/material.dart';

import '../models/conta.dart';
import '../services/api_service.dart';
import '../services/contas_cache.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/bancos.dart';
import '../utils/currency_formatter.dart';
import '../utils/meses.dart';
import '../utils/responsive_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/conta_form_dialog.dart';
import '../widgets/logo_banco.dart';
import '../widgets/shimmer_widgets.dart';
import '../widgets/transferencia_dialog.dart';

/// Contas bancárias da loja, com saldo atual e previsto do mês escolhido.
///
/// Os dois saldos vêm **acumulados** até o fim do mês, não como resultado do mês:
/// `saldoAtual` é o que já está confirmado, `saldoPrevisto` soma o que ainda vai
/// vencer. Saldo de conta que reinicia na virada do mês não é saldo.
///
/// Duas requisições por mês, disparadas em paralelo: os saldos de todas as contas
/// (uma consulta agrupada do lado do servidor, não uma por conta) e as
/// transferências do período.
class ContasPage extends StatefulWidget {
  const ContasPage({super.key});

  @override
  State<ContasPage> createState() => _ContasPageState();
}

class _ContasPageState extends State<ContasPage> {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  late DateTime _mes;
  List<SaldoConta> _saldos = const [];
  List<Transferencia> _transferencias = const [];
  bool _carregando = true;
  Object? _erro;

  /// Cada carga leva um número e só a mais recente pode escrever no estado.
  /// Sem isso, trocar de mês rápido deixa a resposta antiga chegar depois e
  /// repor os saldos do mês anterior — o mesmo cuidado da `FluxosPage`.
  int _geracao = 0;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month);
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
      // Em paralelo: são dois recortes do mesmo mês e nenhum depende do outro.
      final resultado = await Future.wait([
        _apiService.getSaldosContas(ate: fimDoMes(_mes)),
        _apiService.listTransferencias(
          de: DateTime(_mes.year, _mes.month),
          ate: fimDoMes(_mes),
        ),
      ]);

      if (!mounted || geracao != _geracao) return;

      setState(() {
        _saldos = resultado[0] as List<SaldoConta>;
        _transferencias = resultado[1] as List<Transferencia>;
        _carregando = false;
      });
    } catch (e, s) {
      await _logger.logError(
        'ContasPage._carregar',
        e,
        stackTrace: s,
        additionalInfo: {'mes': '${_mes.year}-${_mes.month}'},
      );

      if (!mounted || geracao != _geracao) return;

      setState(() {
        _erro = e;
        _carregando = false;
      });
    }
  }

  void _irParaMes(DateTime mes) {
    setState(() => _mes = DateTime(mes.year, mes.month));
    _carregar();
  }

  /// Contas de verdade: fora o balde "Sem conta", que não se edita, não se apaga
  /// e não participa de transferência.
  List<SaldoConta> get _contas =>
      _saldos.where((c) => !c.semConta).toList();

  /// As que podem receber ou enviar uma transferência, e as que recebem as
  /// movimentações de uma conta apagada.
  List<SaldoConta> get _contasAtivas =>
      _contas.where((c) => c.ativado).toList();

  double get _totalAtual =>
      _saldos.fold(0.0, (soma, c) => soma + c.saldoAtual);

  double get _totalPrevisto =>
      _saldos.fold(0.0, (soma, c) => soma + c.saldoPrevisto);

  // ---------------------------------------------------------------- ações

  Future<void> _novaConta() async {
    final gravou = await showDialog<bool>(
      context: context,
      builder: (_) => const ContaFormDialog(),
    );
    if (gravou == true) _carregar();
  }

  Future<void> _editar(SaldoConta saldo) async {
    // O formulário trabalha com `Conta`; o que a página tem é a conta com os
    // saldos. Os campos editáveis são os mesmos, então converter aqui evita uma
    // consulta só para reabrir o que já está na tela.
    final conta = Conta(
      id: saldo.id,
      idCliente: GlobalState().firstIdLoja,
      descricao: saldo.descricao,
      ativado: saldo.ativado,
      imagem: saldo.imagem,
      saldoInicial: saldo.saldoInicial,
    );

    final gravou = await showDialog<bool>(
      context: context,
      builder: (_) => ContaFormDialog(conta: conta),
    );
    if (gravou == true) _carregar();
  }

  Future<void> _transferir() async {
    final feito = await showDialog<bool>(
      context: context,
      builder: (_) => TransferenciaDialog(contas: _contasAtivas),
    );
    if (feito == true) _carregar();
  }

  /// Apaga a conta perguntando para onde vão as movimentações dela.
  ///
  /// Sem outra conta cadastrada não há escolha a fazer: tudo vai para "sem
  /// conta", e o diálogo só avisa.
  Future<void> _apagar(SaldoConta conta) async {
    final destinos = _contas.where((c) => c.id != conta.id).toList();

    final confirmado = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoApagarConta(conta: conta, destinos: destinos),
    );

    if (confirmado == null) return;

    try {
      await _apiService.deleteConta(conta.id, moverPara: confirmado);
      ContasCache().invalidar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conta "${conta.descricao}" apagada'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _carregar();
    } catch (e, s) {
      await _logger.logError(
        'ContasPage._apagar',
        e,
        stackTrace: s,
        additionalInfo: {'id': conta.id, 'moverPara': confirmado},
      );
      if (mounted) _erroSnack('Não foi possível apagar a conta: $e');
    }
  }

  Future<void> _apagarTransferencia(Transferencia t) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Apagar transferência?'),
            content: Text(
              'As duas movimentações serão apagadas: a saída de '
              '${_nomeConta(t.idContaOrigem)} e a entrada em '
              '${_nomeConta(t.idContaDestino)}.',
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
      await _apiService.deleteTransferencia(t.idTransferencia);
      if (!mounted) return;
      _carregar();
    } catch (e, s) {
      await _logger.logError(
        'ContasPage._apagarTransferencia',
        e,
        stackTrace: s,
        additionalInfo: {'idTransferencia': t.idTransferencia},
      );
      if (mounted) _erroSnack('Não foi possível apagar a transferência: $e');
    }
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

  /// Nome da conta pelo id, para as transferências. A conta pode ter sido
  /// arquivada depois da transferência, mas ela continua na lista — só
  /// desaparecida é que cai no genérico.
  String _nomeConta(int id) {
    for (final c in _saldos) {
      if (c.id == id) return c.descricao;
    }
    return 'conta removida';
  }

  // ---------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    // Transferência exige duas contas ativas; com uma só, o botão não teria para
    // onde mandar o dinheiro.
    final podeTransferir = _contasAtivas.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas'),
        actions: [
          if (podeTransferir)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Transferir entre contas',
              onPressed: _transferir,
            ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _novaConta,
        tooltip: 'Nova conta',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _corpo(),
      ),
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
        titulo: 'Não foi possível carregar as contas',
        descricao: '$_erro',
        acao: FilledButton.icon(
          onPressed: _carregar,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
        ),
      );
    }

    if (_contas.isEmpty) {
      return _centralizado(
        icone: Icons.account_balance,
        titulo: 'Nenhuma conta cadastrada',
        descricao:
            'Cadastre as contas onde o dinheiro da loja entra e sai para '
            'acompanhar o saldo de cada uma. Enquanto não houver conta, os '
            'lançamentos seguem sem conta atribuída — nada do que já existe '
            'muda.',
        acao: FilledButton.icon(
          onPressed: _novaConta,
          icon: const Icon(Icons.add),
          label: const Text('Cadastrar conta'),
        ),
        // O balde "Sem conta" pode ter saldo mesmo sem conta cadastrada; mostrar
        // o total evita a impressão de que não há movimentação nenhuma.
        rodape:
            _saldos.isEmpty
                ? null
                : 'Sem conta: ${CurrencyFormatter.format(_totalAtual)} '
                    'em ${_saldos.first.quantidade} movimentações',
      );
    }

    return ListView(
      padding: context.responsivePadding(),
      children: [
        _navegadorMes(),
        const SizedBox(height: AppSpacing.md),
        _resumo(),
        const SizedBox(height: AppSpacing.lg),
        for (final conta in _saldos) _cartaoConta(conta),
        if (_transferencias.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _tituloSecao(
            'Transferências de ${rotuloMes(_mes).toLowerCase()}',
            Icons.swap_horiz,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final t in _transferencias) _linhaTransferencia(t),
        ],
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
    String? rodape,
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
        if (rodape != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            rodape,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _navegadorMes() {
    final theme = Theme.of(context);
    final agora = DateTime.now();
    final noMesAtual = _mes.year == agora.year && _mes.month == agora.month;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mês anterior',
          visualDensity: VisualDensity.compact,
          onPressed: () => _irParaMes(DateTime(_mes.year, _mes.month - 1)),
        ),
        Expanded(
          child: Text(
            rotuloMes(_mes),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo mês',
          visualDensity: VisualDensity.compact,
          onPressed: () => _irParaMes(DateTime(_mes.year, _mes.month + 1)),
        ),
        if (!noMesAtual)
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Mês atual',
            visualDensity: VisualDensity.compact,
            onPressed: () => _irParaMes(DateTime(agora.year, agora.month)),
          ),
      ],
    );
  }

  /// Total das contas. Soma também o "Sem conta": é dinheiro da loja, e deixá-lo
  /// fora faria o total da página não fechar com o total dos lançamentos.
  Widget _resumo() {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final aConfirmar = _totalPrevisto - _totalAtual;

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
              'Saldo total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              CurrencyFormatter.format(_totalAtual),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _totalAtual < 0 ? cores.error : cores.success,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: cores.info),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Previsto até o fim do mês: '
                    '${CurrencyFormatter.format(_totalPrevisto)}'
                    '${aConfirmar == 0 ? '' : ' (${CurrencyFormatter.format(aConfirmar)} a confirmar)'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoConta(SaldoConta conta) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final nomeBanco = Bancos.nome(conta.imagem);
    final arquivada = !conta.ativado && !conta.semConta;

    // Arquivada e "Sem conta" ficam atenuadas: continuam contando no total, mas
    // não são onde a atenção do lojista deve cair.
    final atenuada = arquivada || conta.semConta;

    return Card(
      elevation: atenuada ? AppElevation.none : AppElevation.card,
      color: atenuada ? theme.colorScheme.surfaceContainerHighest : null,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Opacity(
              opacity: atenuada ? 0.6 : 1,
              child:
                  conta.semConta
                      ? Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.15,
                          ),
                        ),
                        child: Icon(
                          Icons.help_outline,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                      : LogoBanco(
                        chave: conta.imagem,
                        nomeConta: conta.descricao,
                      ),
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
                          conta.descricao,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (arquivada) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _chip('Arquivada', theme.colorScheme.onSurfaceVariant),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conta.semConta
                        ? 'Lançamentos sem conta atribuída'
                        : [
                          if (nomeBanco.isNotEmpty) nomeBanco,
                          '${conta.quantidade} ${conta.quantidade == 1 ? 'movimentação' : 'movimentações'}',
                        ].join(' · '),
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
                  CurrencyFormatter.format(conta.saldoAtual),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: conta.saldoAtual < 0 ? cores.error : cores.success,
                  ),
                ),
                // Previsto repetido não informa nada: só aparece quando difere do
                // atual, que é quando há algo pendente de confirmação.
                if (conta.aConfirmar != 0)
                  Text(
                    'prev. ${CurrencyFormatter.format(conta.saldoPrevisto)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            // "Sem conta" não é conta: nada a editar nem a apagar.
            if (!conta.semConta)
              PopupMenuButton<String>(
                tooltip: 'Opções da conta',
                position: PopupMenuPosition.under,
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (opcao) {
                  if (opcao == 'editar') _editar(conta);
                  if (opcao == 'apagar') _apagar(conta);
                },
                itemBuilder:
                    (context) => const [
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
              )
            else
              const SizedBox(width: AppSpacing.xl),
          ],
        ),
      ),
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

  Widget _tituloSecao(String texto, IconData icone) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icone, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(texto, style: theme.textTheme.titleSmall),
      ],
    );
  }

  Widget _linhaTransferencia(Transferencia t) {
    final theme = Theme.of(context);
    final data = t.data;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: Icon(
        Icons.swap_horiz,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        '${_nomeConta(t.idContaOrigem)} → ${_nomeConta(t.idContaDestino)}',
        style: theme.textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        data == null
            ? CurrencyFormatter.format(t.valor)
            : '${data.day.toString().padLeft(2, '0')}/'
                '${data.month.toString().padLeft(2, '0')} · '
                '${CurrencyFormatter.format(t.valor)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        tooltip: 'Apagar transferência',
        onPressed: () => _apagarTransferencia(t),
      ),
    );
  }
}

/// Confirmação do delete, com a escolha de para onde vão as movimentações.
///
/// Devolve no `pop` o id da conta de destino (0 = "deixar sem conta"), ou nada
/// quando o usuário cancela. O 0 é uma escolha válida, então não serve como
/// sinal de cancelamento — daí o `int?` em vez de `bool`.
class _DialogoApagarConta extends StatefulWidget {
  final SaldoConta conta;

  /// As outras contas da loja, incluindo as arquivadas: o destino pode
  /// perfeitamente ser uma conta que não se usa mais para lançar.
  final List<SaldoConta> destinos;

  const _DialogoApagarConta({required this.conta, required this.destinos});

  @override
  State<_DialogoApagarConta> createState() => _DialogoApagarContaState();
}

class _DialogoApagarContaState extends State<_DialogoApagarConta> {
  /// 0 é "deixar sem conta", e é o padrão: mover para outra conta altera o saldo
  /// dela, então é melhor que seja uma escolha deliberada.
  int _destino = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conta = widget.conta;
    final temMovimentacoes = conta.quantidade > 0;
    final quantas =
        '${conta.quantidade} ${conta.quantidade == 1 ? 'movimentação' : 'movimentações'}';

    return AlertDialog(
      title: Text('Apagar "${conta.descricao}"?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!temMovimentacoes)
            const Text('Esta conta não tem movimentação registrada.')
          else if (widget.destinos.isEmpty)
            Text(
              'Esta conta tem $quantas. Como não há outra conta cadastrada, '
              'elas ficarão sem conta atribuída — nenhum lançamento é apagado.',
            )
          else ...[
            Text('Esta conta tem $quantas. Para onde movê-las?'),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              value: _destino,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Mover para',
              ),
              items: [
                const DropdownMenuItem(
                  value: 0,
                  child: Text('Deixar sem conta'),
                ),
                for (final d in widget.destinos)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      d.ativado ? d.descricao : '${d.descricao} (arquivada)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _destino = v ?? 0),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'A conta é removida; os lançamentos continuam existindo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.appColors.error,
          ),
          onPressed: () => Navigator.of(context).pop(_destino),
          child: const Text('Apagar'),
        ),
      ],
    );
  }
}
