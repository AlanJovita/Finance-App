import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/global_state.dart';

/// Envolve toda rota interna: nenhuma tela do app monta sem `id_cliente`.
///
/// **O problema que ela resolve não é o login — é o recarregamento.** Em web, a
/// rota em foco vai para a URL do navegador (`/receitas`, `/contas`, …). Sair do
/// site e voltar pelo botão "avançar" recarrega o app **direto naquela rota**,
/// e o `AuthWrapper` — que é só a rota raiz — nunca entra na jogada. A tela
/// interna montava com a sessão vazia, `GlobalState.idCliente` respondia 0, e
/// aí: as listas vinham do "cliente 0" (dados de outra origem, contas da loja
/// real ausentes) e um lançamento feito ali era gravado com `id_cliente = 0`.
///
/// Por isso a guarda tem **três** respostas, e não duas:
///
/// - sessão ainda carregando → espera. A leitura do disco é assíncrona e o
///   frame não espera por ela; montar a tela aqui é o que disparava as
///   requisições com 0 um instante antes de a sessão chegar.
/// - sem sessão → volta ao login, com aviso.
/// - sessão válida → monta a tela.
///
/// A volta é `popUntil` até a raiz, e não `pushNamedAndRemoveUntil('/login')`,
/// pelo motivo documentado em `utils/auth_actions.dart`: quem decide entre
/// login e dashboard é o `AuthWrapper` da raiz, e tirá-lo da pilha deixaria o
/// usuário preso na tela de login depois de autenticar.
class GuardaSessao extends StatefulWidget {
  final Widget child;

  /// Nome da rota, só para o log de quem foi barrado.
  final String rota;

  const GuardaSessao({super.key, required this.rota, required this.child});

  @override
  State<GuardaSessao> createState() => _GuardaSessaoState();
}

class _GuardaSessaoState extends State<GuardaSessao> {
  /// Já viu uma sessão válida nesta tela? `false` no primeiro build é o que
  /// separa os dois jeitos de chegar aqui sem sessão: a tela aberta por
  /// recarregamento (nunca teve sessão — avisa) e o "Sair" do menu, que
  /// invalida a sessão de uma tela que estava funcionando (não avisa; o usuário
  /// pediu).
  bool _tinhaSessao = false;
  bool _saindo = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.sessaoCarregando) return const EsperaSessao();

    // As duas fontes são conferidas: o provider é quem a UI escuta, e o
    // `GlobalState` é quem o `ApiService` lê. Divergência entre os dois é
    // exatamente o estado em que a tela parece logada e a requisição sai com 0.
    if (!auth.sessaoValida || !GlobalState().sessaoValida) {
      _voltarAoLogin(auth, avisar: !_tinhaSessao);
      return const EsperaSessao();
    }

    _tinhaSessao = true;
    return widget.child;
  }

  void _voltarAoLogin(AuthProvider auth, {required bool avisar}) {
    if (_saindo) return;
    _saindo = true;

    // Capturados agora: depois do pop este State está desmontado e o context
    // não serve mais para procurar Navigator nem ScaffoldMessenger. O
    // messenger é o do MaterialApp, acima do Navigator, então ele sobrevive à
    // troca de rota e mostra o aviso já na tela de login.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.popUntil((rota) => rota.isFirst);

      if (!avisar) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sessão encerrada. Entre novamente para continuar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Sem `await` de propósito: `encerrarSessaoInvalida` registra o caso no
      // log remoto, que tem timeout de 10s, e a volta ao login não pode ficar
      // esperando por isso. A limpeza do estado em memória é síncrona lá
      // dentro.
      auth.encerrarSessaoInvalida(widget.rota);
    });
  }
}

/// A espera enquanto a sessão gravada está sendo lida.
///
/// Deliberadamente sem texto: na prática ela dura um ou dois frames, e uma
/// mensagem que aparece e desaparece nesse tempo só pisca.
class EsperaSessao extends StatelessWidget {
  const EsperaSessao({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
