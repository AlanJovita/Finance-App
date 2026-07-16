import 'dart:convert';

class TokenService {
  /// Codifica um CNPJ em Base64
  static String encodeToken(String cnpj) {
    // Remove caracteres especiais do CNPJ
    final cnpjLimpo = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    final bytes = utf8.encode(cnpjLimpo);
    return base64Url.encode(bytes).replaceAll('=', ''); // Remove padding
  }

  /// Decodifica um token Base64 para CNPJ
  static String? decodeToken(String token) {
    try {
      // Adiciona padding se necessário
      String paddedToken = token;
      while (paddedToken.length % 4 != 0) {
        paddedToken += '=';
      }

      final bytes = base64Url.decode(paddedToken);
      final cnpj = utf8.decode(bytes);

      return cnpj;
    } catch (e) {
      return null;
    }
  }

  /// Valida se um CNPJ é válido (formato básico)
  static bool isValidCNPJ(String cnpj) {
    final cnpjLimpo = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    return cnpjLimpo.isNotEmpty;
  }
}
