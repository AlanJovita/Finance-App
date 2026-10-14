import 'dart:js_interop';

/// Armazenamento por aba, em web: o `sessionStorage` do navegador.
///
/// É o que faz a sessão **sem** "lembrar login" sobreviver a um F5 e ao
/// voltar/avançar do navegador — que é justamente o gesto que recarregava o app
/// inteiro e o deixava sem `id_cliente` — e morrer quando a aba fecha. O
/// `localStorage`, que é onde o SharedPreferences grava na web, duraria demais:
/// quem não marcou a opção não pediu para ficar logado no computador.
///
/// `sessionStorage` não é alcançável em toda situação (iframe com sandbox,
/// armazenamento bloqueado pelo navegador), e lá ele **lança**. Como a falta
/// dele só custa um login a mais, tudo aqui engole a exceção: a gêmea em
/// memória (`armazenamento_volatil_memoria.dart`) é o fallback natural do
/// comportamento, não um erro para o usuário.
class ArmazenamentoVolatil {
  static String? ler(String chave) {
    try {
      return _janela.sessionStorage?.getItem(chave);
    } catch (_) {
      return null;
    }
  }

  static void gravar(String chave, String valor) {
    try {
      _janela.sessionStorage?.setItem(chave, valor);
    } catch (_) {
      // Sessão fica só em memória nesta aba.
    }
  }

  static void apagar(String chave) {
    try {
      _janela.sessionStorage?.removeItem(chave);
    } catch (_) {
      // Nada a apagar se nem dá para abrir o armazenamento.
    }
  }
}

@JS('window')
external _Janela get _janela;

/// O mínimo de `package:web` que esta classe usa — declarado aqui para o app
/// não ganhar uma dependência direta por três chamadas. Extension type, e não
/// função externa com caminho pontilhado (`@JS('window.sessionStorage.getItem')`):
/// aquela forma chamaria o método solto, sem o `this` do Storage, e o navegador
/// recusa com "Illegal invocation".
extension type _Janela(JSObject _) implements JSObject {
  external _Armazenamento? get sessionStorage;
}

extension type _Armazenamento(JSObject _) implements JSObject {
  external String? getItem(String chave);
  external void setItem(String chave, String valor);
  external void removeItem(String chave);
}
