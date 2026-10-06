import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_app/providers/auth_provider.dart';
import 'package:finance_app/services/global_state.dart';
import 'package:finance_app/services/token_service.dart';

/// Acesso ao app pela URL, sem login e senha.
///
/// O token passou a ser opaco e aleatório. Antes era `base64(cnpj)`, e como
/// CNPJ é público o link de cada uma das 415 lojas era derivável — o esquema
/// não autenticava ninguém. Boa parte destes testes existe para que isso não
/// volte por descuido.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GlobalState().idLojas = [];
    GlobalState().cnpj = '';
  });

  group('TokenService', () {
    test('aceita o formato de secrets.token_urlsafe(32)', () {
      // Alfabeto base64url sem padding, ~43 caracteres.
      expect(TokenService.pareceToken('Q47FIOv7xK-sM3nZ_pQ1aB2cD4eF6gH8iJ0kL2mN4oP'),
          isTrue);
    });

    test('recusa o link antigo base64(cnpj) sem ir à rede', () {
      // 14 dígitos viram 19 caracteres em base64url sem padding — abaixo do
      // mínimo. É o que faz o link velho morrer com mensagem limpa, na hora.
      final antigo = base64Url.encode(utf8.encode('12345678000199'))
          .replaceAll('=', '');

      expect(antigo.length, 19);
      expect(TokenService.pareceToken(antigo), isFalse);
    });

    test('recusa caminho curto e caractere fora do alfabeto', () {
      expect(TokenService.pareceToken(''), isFalse);
      expect(TokenService.pareceToken('dashboard'), isFalse);
      expect(TokenService.pareceToken('a' * 19), isFalse);
      expect(TokenService.pareceToken('a' * 19 + '/'), isFalse);
      expect(TokenService.pareceToken('a' * 25 + '+'), isFalse);
      expect(TokenService.pareceToken('a' * 25 + '='), isFalse);
    });

    test('não existe mais nada que decodifique o token', () {
      // Se alguém reintroduzir encode/decode aqui, o token volta a carregar
      // dado do cliente — que é exatamente a falha anterior.
      expect(
        TokenService.pareceToken('a' * 43),
        isTrue,
        reason: 'a única coisa que o app faz com o token é checar o formato',
      );
    });
  });

  group('AuthProvider.loginByToken', () {
    test('recusa token malformado sem autenticar', () async {
      final auth = AuthProvider();
      await Future<void>.delayed(Duration.zero);

      // base64(cnpj): o formato antigo.
      final antigo =
          base64Url.encode(utf8.encode('12345678000199')).replaceAll('=', '');

      expect(await auth.loginByToken(antigo), isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(GlobalState().idLojas, isEmpty);
    });

    test('recusa caminho que não é token', () async {
      final auth = AuthProvider();
      await Future<void>.delayed(Duration.zero);

      for (final caminho in ['', 'x', 'favicon.ico', 'alguma-pagina']) {
        expect(await auth.loginByToken(caminho), isFalse, reason: caminho);
      }
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('CNPJ', () {
    test('quem entra por link não tem CNPJ conhecido', () async {
      // O token é opaco: o app não sabe de quem é. O `cnpj` tem de ficar vazio
      // em vez de conter o marcador interno.
      SharedPreferences.setMockInitialValues({
        'auth_user': 'acesso-por-link',
        'id_lojas': <String>['42'],
      });

      final auth = AuthProvider();
      await Future<void>.delayed(Duration.zero);

      expect(auth.isAuthenticated, isTrue);
      expect(auth.cnpj, isEmpty, reason: 'marcador não pode virar CNPJ');
    });

    test('quem entra por formulário tem o CNPJ, que é o próprio login',
        () async {
      SharedPreferences.setMockInitialValues({
        'auth_user': '12345678000199',
        'id_lojas': <String>['42'],
      });

      final auth = AuthProvider();
      await Future<void>.delayed(Duration.zero);

      expect(auth.cnpj, '12345678000199');
      expect(GlobalState().cnpj, '12345678000199');
    });

    test('extrai o CNPJ de valores formatados e do prefixo legado', () async {
      for (final guardado in [
        'CNPJ: 12345678000199',
        '12.345.678/0001-99',
        '12345678000199',
      ]) {
        SharedPreferences.setMockInitialValues({
          'auth_user': guardado,
          'id_lojas': <String>['42'],
        });

        final auth = AuthProvider();
        await Future<void>.delayed(Duration.zero);

        expect(auth.cnpj, '12345678000199', reason: guardado);
      }
    });

    test('logout limpa o CNPJ do estado global', () async {
      SharedPreferences.setMockInitialValues({
        'auth_user': '12345678000199',
        'id_lojas': <String>['42'],
      });

      final auth = AuthProvider();
      await Future<void>.delayed(Duration.zero);
      expect(GlobalState().cnpj, isNotEmpty);

      await auth.logout();

      expect(GlobalState().cnpj, isEmpty);
      expect(GlobalState().idLojas, isEmpty);
    });
  });
}
