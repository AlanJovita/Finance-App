/// Token de acesso por URL.
///
/// O token é **opaco**: o app não o decodifica nem extrai nada dele, só repassa
/// à API, que valida contra o hash guardado no banco.
///
/// Antes era `base64(cnpj)` e o app decodificava para descobrir o CNPJ. Como
/// CNPJ é informação pública, o link de qualquer loja era derivável — o esquema
/// não autenticava nada. Se precisar de algum dado do usuário aqui, peça à API
/// depois de validar o token; não volte a embutir dado no token.
class TokenService {
  /// Tamanho mínimo plausível para `secrets.token_urlsafe(32)` (~43 chars).
  ///
  /// Serve só para não gastar uma requisição com um caminho que claramente não
  /// é token — quem decide de verdade é a API.
  static const int _tamanhoMinimo = 20;

  /// Alfabeto do `token_urlsafe`: base64url sem padding.
  static final RegExp _formato = RegExp(r'^[A-Za-z0-9_-]+$');

  /// O caminho da URL parece um token de acesso?
  static bool pareceToken(String token) =>
      token.length >= _tamanhoMinimo && _formato.hasMatch(token);
}
