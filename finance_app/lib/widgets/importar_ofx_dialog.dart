import 'package:flutter/material.dart';

import '../models/cartao.dart';
import '../models/categoria.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import '../utils/ofx.dart';
import '../utils/ofx_importacao.dart';
import '../utils/responsive_utils.dart';

/// Revisão do extrato OFX antes de gravar — a tela que decide o que entra.
///
/// Recebe o extrato **já lido**: quem escolhe o arquivo é a página, porque na
/// web o seletor de arquivo só abre dentro do gesto do usuário, e um
/// `pickFile()` disparado depois da animação do diálogo pode ser bloqueado pelo
/// navegador. Aqui dentro não há nada de `file_picker`, o que também deixa este
/// widget testável sem plugin.
///
/// Importar em lote é o oposto de um formulário: ninguém confere 24 linhas num
/// modal de campos. Então a lista é o formulário — cada linha é um checkbox com
/// o que o banco mandou, e a única decisão coletiva (a categoria) fica no topo.
class ImportarOfxDialog extends StatefulWidget {
  final Cartao cartao;
  final ExtratoOfx extrato;
  final String nomeArquivo;

  /// Os movimentos que a fatura em foco já tem — a base da conciliação.
  final List<MovimentoCartao> movimentos;

  /// Categorias de **despesa** (`tipo_fluxo = 2`), que é a natureza de uma
  /// compra. A categoria do lote não se aplica aos créditos: um estorno com
  /// categoria de despesa diria que o dinheiro saiu.
  final List<Categoria> categorias;

  /// Quantos entraram e quantos falharam. Quem avisa o usuário e recarrega a
  /// fatura é a página, como no `onSalvou` do formulário de lançamento.
  final void Function(int importados, int falhas) onImportou;

  const ImportarOfxDialog({
    super.key,
    required this.cartao,
    required this.extrato,
    required this.nomeArquivo,
    required this.movimentos,
    required this.categorias,
    required this.onImportou,
  });

  @override
  State<ImportarOfxDialog> createState() => _ImportarOfxDialogState();
}

class _ImportarOfxDialogState extends State<ImportarOfxDialog> {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  late final List<ItemImportacaoOfx> _itens = conciliarOfx(
    lancamentos: widget.extrato.lancamentos,
    existentes: widget.movimentos,
  );

  int _categoriaId = 0;
  bool _importando = false;

  /// Quantas linhas já foram gravadas — o POST é um por lançamento, e numa
  /// importação de 24 um spinner sem número parece travado.
  int _gravados = 0;

  List<ItemImportacaoOfx> get _marcados =>
      _itens.where((i) => i.marcado).toList();

  /// O extrato cobre o ciclo deste cartão?
  ///
  /// `DTEND` é o fim do ciclo no banco; se ele não cai no dia de fechamento
  /// cadastrado, as compras vão se espalhar entre duas faturas — a API resolve
  /// a fatura pela data da compra e pelo ciclo **cadastrado**, não pelo
  /// arquivo. Avisar é barato; adivinhar o dia certo e reescrever o cadastro
  /// não é decisão de um importador.
  bool get _cicloDivergente {
    final fim = widget.extrato.fim;
    if (fim == null) return false;

    return fim.day != widget.cartao.diaFechamento;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estreito = ResponsiveUtils.isMobile(context);

    // Fechar no meio da gravação deixaria o resto do lote sem gravar **e** sem
    // aviso: o laço para no primeiro `mounted` falso e a fatura atrás não
    // recarrega. `PopScope` cobre o botão voltar e o toque fora, que é o que o
    // `barrierDismissible` do `showDialog` dispara.
    return PopScope(
      canPop: !_importando,
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Importar lançamentos'),
            const SizedBox(height: 2),
            Text(
              widget.nomeArquivo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        content: SizedBox(
          width: estreito ? double.maxFinite : 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _resumo(theme),
              const SizedBox(height: AppSpacing.md),
              _seletorCategoria(),
              const SizedBox(height: AppSpacing.sm),
              _cabecalhoLista(theme),
              // A lista rola dentro do diálogo: 24 linhas não cabem em tela
              // nenhuma, e deixar o diálogo crescer o faria estourar a altura.
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _itens.length,
                  itemBuilder: (_, i) => _linha(theme, _itens[i]),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _importando ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          _importando
              ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  '$_gravados de ${_marcados.length}…',
                  style: theme.textTheme.labelLarge,
                ),
              )
              : ElevatedButton(
                onPressed: _marcados.isEmpty ? null : _importar,
                child: Text(
                  _marcados.isEmpty
                      ? 'Nada a importar'
                      : 'Importar ${_marcados.length}',
                ),
              ),
        ],
      ),
    );
  }

  Widget _resumo(ThemeData theme) {
    final e = widget.extrato;
    final cores = context.appColors;
    final estilo = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${e.lancamentos.length} lançamentos'
          '${e.inicio == null || e.fim == null ? '' : ' · ${_dia(e.inicio!)} a ${_dia(e.fim!)}'}',
          style: estilo,
        ),
        Text(
          'Compras: ${CurrencyFormatter.format(e.totalDebitos)}'
          '${e.saldo == null ? '' : ' · fatura no banco: ${CurrencyFormatter.format(e.saldo)}'}',
          style: estilo,
        ),
        if (e.ignorados > 0)
          _aviso(
            theme,
            cores.error,
            Icons.error_outline,
            '${e.ignorados} ${e.ignorados == 1 ? 'linha' : 'linhas'} sem data ou '
            'valor legível foram descartadas.',
          ),
        if (_cicloDivergente)
          _aviso(
            theme,
            cores.warning,
            Icons.warning_amber_outlined,
            'O extrato fecha dia ${widget.extrato.fim!.day} e o cartão está '
            'cadastrado para fechar dia ${widget.cartao.diaFechamento}. '
            'Os lançamentos vão cair na fatura que o cadastro determina.',
          ),
      ],
    );
  }

  Widget _aviso(ThemeData theme, Color cor, IconData icone, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodySmall?.copyWith(color: cor),
            ),
          ),
        ],
      ),
    );
  }

  /// A única decisão que vale para todas as linhas.
  ///
  /// Padrão "Sem categoria", igual à despesa que o fechamento da fatura gera:
  /// categorizar fino continua sendo a edição de cada movimento, que já existe.
  Widget _seletorCategoria() {
    return DropdownButtonFormField<int>(
      value: _categoriaId,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'Categoria das compras',
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('Sem categoria')),
        for (final c in widget.categorias)
          if (c.id != null)
            DropdownMenuItem(value: c.id, child: Text(c.descricao)),
      ],
      onChanged:
          _importando
              ? null
              : (valor) => setState(() => _categoriaId = valor ?? 0),
    );
  }

  /// Marcar/desmarcar em bloco, **assimétrico de propósito**.
  ///
  /// Marcar atinge só as linhas novas: incluir as que a fatura já tem
  /// duplicaria lançamento num toque, e elas estão marcáveis uma a uma
  /// justamente porque reimportar deliberadamente é decisão do usuário.
  /// Desmarcar atinge tudo que está marcado — nessa direção não há risco.
  Widget _cabecalhoLista(ThemeData theme) {
    final novos = _itens.where((i) => i.situacao == SituacaoOfx.novo).toList();
    final todosMarcados = novos.isNotEmpty && novos.every((i) => i.marcado);

    void alternar(bool marcar) {
      setState(() {
        if (marcar) {
          for (final i in novos) {
            i.marcado = true;
          }
        } else {
          for (final i in _itens) {
            i.marcado = false;
          }
        }
      });
    }

    final habilitado = !_importando && novos.isNotEmpty;

    // O rótulo faz parte do alvo: num celular, acertar só o quadradinho do
    // checkbox para uma ação de cabeçalho é pedir precisão que ninguém tem.
    return InkWell(
      onTap: habilitado ? () => alternar(!todosMarcados) : null,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        children: [
          Checkbox(
            value: todosMarcados,
            tristate: false,
            onChanged: habilitado ? (valor) => alternar(valor == true) : null,
          ),
          Text(
            todosMarcados ? 'Desmarcar todos' : 'Marcar todos',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }

  Widget _linha(ThemeData theme, ItemImportacaoOfx item) {
    final cores = context.appColors;
    final l = item.lancamento;

    return CheckboxListTile(
      value: item.marcado,
      onChanged:
          _importando || !item.podeMarcar
              ? null
              : (valor) => setState(() => item.marcado = valor == true),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      title: Text(
        l.descricao,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Row(
        children: [
          Text(_dia(l.data), style: theme.textTheme.bodySmall),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _marcador(theme, cores, item)),
        ],
      ),
      secondary: Text(
        CurrencyFormatter.format(l.valor),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: l.credito ? cores.success : cores.error,
        ),
      ),
    );
  }

  /// O rótulo que explica o estado da linha — e, no crédito, o seletor de
  /// natureza, que é a única escolha por linha desta tela.
  Widget _marcador(ThemeData theme, AppColors cores, ItemImportacaoOfx item) {
    final parcela = item.lancamento.parcela;

    switch (item.situacao) {
      case SituacaoOfx.pagamento:
        return _texto(theme, cores.info, 'pagamento — registre pela fatura');
      case SituacaoOfx.jaImportado:
        return _texto(
          theme,
          theme.colorScheme.onSurfaceVariant,
          'já na fatura',
        );
      case SituacaoOfx.credito:
        return Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<NaturezaMovimento>(
            value: item.natureza,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: theme.textTheme.bodySmall,
            items: [
              for (final n in NaturezaMovimento.creditosLancaveis)
                DropdownMenuItem(value: n, child: Text(n.rotulo)),
            ],
            onChanged:
                _importando
                    ? null
                    : (valor) => setState(() {
                      if (valor != null) item.natureza = valor;
                    }),
          ),
        );
      case SituacaoOfx.novo:
        // O "Parcela 5/12" aparece porque é o que distingue duas linhas quase
        // iguais do mesmo estabelecimento — e porque deixa claro que cada
        // parcela entra como um lançamento só.
        return parcela == null
            ? const SizedBox.shrink()
            : _texto(
              theme,
              theme.colorScheme.onSurfaceVariant,
              'parcela $parcela',
            );
    }
  }

  Widget _texto(ThemeData theme, Color cor, String texto) => Text(
    texto,
    style: theme.textTheme.bodySmall?.copyWith(color: cor),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  String _dia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// Grava um POST por lançamento.
  ///
  /// Sequencial de propósito: a API resolve (ou cria) a fatura dentro do INSERT
  /// e o `uk_fcf_cartao_competencia` é o que torna esse get-or-create seguro —
  /// mas disparar 24 em paralelo faria 24 tentativas de criar a mesma fatura ao
  /// mesmo tempo, trocando uma importação tranquila por uma corrida que depende
  /// do retry do servidor.
  ///
  /// **Uma falha no meio não interrompe o resto**, e também não desfaz o que já
  /// entrou: a próxima importação do mesmo arquivo reconhece o que está na
  /// fatura e oferece só o que falta — que é exatamente para isso que a
  /// conciliação existe.
  Future<void> _importar() async {
    final paraImportar = _marcados;
    if (paraImportar.isEmpty) return;

    setState(() {
      _importando = true;
      _gravados = 0;
    });

    var falhas = 0;

    for (final item in paraImportar) {
      final movimento = item.paraMovimento(
        idCliente: GlobalState().firstIdLoja,
        idCartao: widget.cartao.id,
        // Categoria do lote só nas compras: ver a nota em [categorias].
        idCategoria: item.lancamento.credito ? 0 : _categoriaId,
      );
      if (movimento == null) continue;

      try {
        await _apiService.createMovimentoCartao(movimento);
        if (!mounted) return;
        setState(() => _gravados++);
      } catch (e, s) {
        falhas++;
        // Por lançamento, e com o que ele era: numa importação de 24, "deu erro"
        // sem dizer qual linha não permite refazer nada.
        await _logger.logError(
          'ImportarOfxDialog._importar',
          e,
          stackTrace: s,
          additionalInfo: {
            'descricao': item.lancamento.descricao,
            'valor': item.lancamento.valor,
            'data': item.lancamento.data.toIso8601String(),
            'idCartao': widget.cartao.id,
          },
        );
      }
    }

    if (!mounted) return;

    Navigator.of(context).pop();
    widget.onImportou(_gravados, falhas);
  }
}
