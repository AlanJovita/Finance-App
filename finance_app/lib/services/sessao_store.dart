import 'package:shared_preferences/shared_preferences.dart';

import 'armazenamento_volatil_memoria.dart'
    if (dart.library.js_interop) 'armazenamento_volatil_web.dart';

/// Sessão guardada no dispositivo: usuário e lojas, nada mais.
///
/// Credencial não entra aqui — nem a senha do formulário, nem o token do link
/// de acesso (ver `AuthProvider.loginByToken`).
class SessaoSalva {
  final String user;
  final List<int> idLojas;

  const SessaoSalva({required this.user, required this.idLojas});

  int get idCliente => idLojas.first;
}

/// Onde a sessão é guardada — e por quanto tempo.
///
/// São **dois** destinos, escolhidos pelo "lembrar login" do formulário:
///
/// - marcado: `SharedPreferences` (no navegador, `localStorage`), que sobrevive
///   a fechar o app e o navegador. É o que a opção promete.
/// - desmarcado: [ArmazenamentoVolatil], que dura o que a aba durar. Não é
///   conforto gratuito: sem isso, um F5 — ou o voltar/avançar do navegador, que
///   recarrega o app inteiro — deixava o usuário dentro de uma tela interna com
///   a sessão vazia, e `id_cliente` caía para 0.
///
/// Quem grava com "lembrar" escreve nos dois, para o recarregamento ser
/// atendido pelo mais barato e pelo mais recente.
///
/// **Toda leitura valida.** `user` vazio ou lista sem nenhum id positivo não é
/// sessão: é devolvido `null` e o lixo é apagado, senão a mesma chave
/// corrompida reabriria o app sem `id_cliente` em cada abertura.
class SessaoStore {
  static const chaveUser = 'auth_user';
  static const chaveIdLojas = 'id_lojas';

  /// Separador da lista no armazenamento volátil, que só guarda texto.
  static const _separador = ',';

  static Future<void> gravar({
    required String user,
    required List<int> idLojas,
    required bool lembrar,
  }) async {
    final ids = lojasValidas(idLojas);
    if (user.isEmpty || ids.isEmpty) return;

    ArmazenamentoVolatil.gravar(chaveUser, user);
    ArmazenamentoVolatil.gravar(
      chaveIdLojas,
      ids.map((i) => i.toString()).join(_separador),
    );

    // Sem "lembrar" o destino persistido não é tocado — nem para apagar. Ele
    // é compartilhado entre as abas, e limpá-lo aqui derrubaria a sessão
    // lembrada de outra aba. Não há sobra de sessão antiga nesse caminho: para
    // chegar ao formulário de login é preciso ter saído, e a saída apaga os
    // dois destinos.
    if (!lembrar) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chaveUser, user);
    await prefs.setStringList(
      chaveIdLojas,
      ids.map((i) => i.toString()).toList(),
    );
  }

  /// A sessão desta aba, ou a persistida, ou `null`.
  ///
  /// A volátil tem precedência: ela é sempre a mais recente — quem entrou com
  /// "lembrar" escreveu nas duas, e quem entrou sem ele só na volátil.
  static Future<SessaoSalva?> ler() async {
    final doVolatil = _lerVolatil();
    if (doVolatil != null) return doVolatil;

    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString(chaveUser);
    final ids = lojasValidas(
      (prefs.getStringList(chaveIdLojas) ?? const []).map(
        (s) => int.tryParse(s) ?? 0,
      ),
    );

    if (user == null || user.isEmpty || ids.isEmpty) {
      // Chave pela metade ou com id inválido: apaga para não repetir a dúvida
      // na próxima abertura.
      if (user != null || ids.isNotEmpty) await limpar();
      return null;
    }

    return SessaoSalva(user: user, idLojas: ids);
  }

  static Future<void> limpar() async {
    ArmazenamentoVolatil.apagar(chaveUser);
    ArmazenamentoVolatil.apagar(chaveIdLojas);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(chaveUser);
    await prefs.remove(chaveIdLojas);
  }

  static SessaoSalva? _lerVolatil() {
    final user = ArmazenamentoVolatil.ler(chaveUser);
    final bruto = ArmazenamentoVolatil.ler(chaveIdLojas);
    if (user == null || user.isEmpty || bruto == null) return null;

    final ids = lojasValidas(
      bruto.split(_separador).map((s) => int.tryParse(s.trim()) ?? 0),
    );
    if (ids.isEmpty) return null;

    return SessaoSalva(user: user, idLojas: ids);
  }

  /// Ids de loja utilizáveis: descarta 0, negativo e repetido.
  ///
  /// Mesma regra do setter de `GlobalState.idLojas`, aplicada antes de gravar e
  /// depois de ler — é o que impede uma sessão de nascer apontando para o
  /// cliente 0, venha o zero da resposta do login ou do disco.
  static List<int> lojasValidas(Iterable<int> bruto) {
    final vistos = <int>{};
    return [
      for (final id in bruto)
        if (id > 0 && vistos.add(id)) id,
    ];
  }
}
