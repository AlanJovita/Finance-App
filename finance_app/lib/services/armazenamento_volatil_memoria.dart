/// Armazenamento que morre com o processo — a implementação padrão, usada em
/// tudo que não é web (Android, iOS, Windows, Linux, macOS e os testes).
///
/// Nessas plataformas "enquanto a aba estiver aberta" é o próprio tempo de vida
/// do app: fechar e reabrir já cria um processo novo, então um mapa em memória
/// tem exatamente a durabilidade que a sessão sem "lembrar login" precisa. A
/// gêmea de web (`armazenamento_volatil_web.dart`) usa o `sessionStorage`, que
/// é o equivalente por aba e sobrevive ao recarregamento da página.
class ArmazenamentoVolatil {
  static final Map<String, String> _dados = {};

  static String? ler(String chave) => _dados[chave];

  static void gravar(String chave, String valor) => _dados[chave] = valor;

  static void apagar(String chave) => _dados.remove(chave);
}
