import 'package:flutter/material.dart';

import '../utils/app_tokens.dart';
import '../utils/bancos.dart';
import '../utils/responsive_utils.dart';
import 'logo_banco.dart';

/// Campo que mostra a instituição escolhida e abre a busca ao ser tocado.
///
/// Não é uma grade inline como o [SeletorCategoria]: o catálogo tem dezenas de
/// entradas e elas não cabem num formulário de diálogo sem empurrar o botão
/// Salvar fora da tela. A busca em diálogo também é como quem cadastra pensa —
/// digita "nu", "341", "caixa".
class SeletorBanco extends StatelessWidget {
  /// Chave do catálogo, ou `null` para "nenhuma instituição".
  final String? selecionado;

  /// Nome que o lojista deu à conta — as iniciais do fallback saem dele.
  final String nomeConta;

  final ValueChanged<String?> onSelecionar;

  const SeletorBanco({
    super.key,
    required this.selecionado,
    required this.nomeConta,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = Bancos.de(selecionado);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => _abrir(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            LogoBanco(chave: selecionado, nomeConta: nomeConta, diametro: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instituição',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item?.nome ?? 'Nenhuma — toque para escolher',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          item == null
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (item != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remover instituição',
                visualDensity: VisualDensity.compact,
                onPressed: () => onSelecionar(null),
              ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context) async {
    // `_Escolhido` em vez de String?: fechar sem escolher e escolher "nenhuma"
    // são coisas diferentes, e `null` puro não distinguiria as duas.
    final escolha = await showDialog<_Escolhido>(
      context: context,
      builder: (_) => _DialogoBancos(selecionado: selecionado),
    );

    if (escolha != null) onSelecionar(escolha.chave);
  }
}

/// Resultado do diálogo. Existe só para separar "cancelou" de "escolheu nenhuma".
class _Escolhido {
  final String? chave;
  const _Escolhido(this.chave);
}

class _DialogoBancos extends StatefulWidget {
  final String? selecionado;

  const _DialogoBancos({required this.selecionado});

  @override
  State<_DialogoBancos> createState() => _DialogoBancosState();
}

class _DialogoBancosState extends State<_DialogoBancos> {
  final _buscaController = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largura =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : 420.0;

    final chaves = Bancos.buscar(_busca);

    return AlertDialog(
      title: const Text('Instituição'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: largura,
        // Altura limitada: a lista rola dentro do diálogo em vez de o diálogo
        // crescer até estourar a tela em telefone pequeno.
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            TextField(
              controller: _buscaController,
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Nome ou número do banco',
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child:
                  chaves.isEmpty
                      ? Center(
                        child: Text(
                          'Nenhuma instituição encontrada',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                      : ListView.builder(
                        // A lista é curta e estável; construir sob demanda já
                        // evita montar as dezenas de tiles de uma vez.
                        itemCount: chaves.length,
                        itemBuilder: (context, i) => _tile(chaves[i]),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _Escolhido(null)),
          child: const Text('Sem instituição'),
        ),
      ],
    );
  }

  Widget _tile(String chave) {
    final item = Bancos.catalogo[chave]!;
    final selecionado = chave == widget.selecionado;

    return ListTile(
      dense: true,
      selected: selecionado,
      leading: LogoBanco(chave: chave, nomeConta: item.nome, diametro: 36),
      title: Text(item.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
      // O código COMPE é o que o lojista confere no extrato; e para carteira e
      // cofre, que não têm código, mostrar a chave não diria nada.
      subtitle: item.temLogo ? Text(chave) : null,
      trailing: selecionado ? const Icon(Icons.check, size: 18) : null,
      onTap: () => Navigator.of(context).pop(_Escolhido(chave)),
    );
  }
}
