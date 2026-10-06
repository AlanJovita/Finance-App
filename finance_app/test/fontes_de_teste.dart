import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrega a Roboto real do SDK.
///
/// Sem isto o teste desenha com a Ahem, em que todo caractere é um quadrado de
/// 1em — muito mais larga que a fonte de verdade. A imagem fica ilegível e,
/// pior, acusa estouro de largura onde não há. Para decidir espaçamento é
/// preciso a métrica real.
Future<void> carregarRoboto() async {
  // FLUTTER_ROOT é exportado pelo `flutter test`; o caminho fixo é só a rede de
  // segurança para quem roda o test runner direto.
  final raiz = Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter';
  final arquivo = File(
    '$raiz${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
    '${Platform.pathSeparator}artifacts${Platform.pathSeparator}material_fonts'
    '${Platform.pathSeparator}roboto-regular.ttf',
  );

  if (!arquivo.existsSync()) {
    // Sem a fonte real o teste desenha em Ahem e as imagens não batem com as
    // gravadas. Falhar aqui, com a causa, é melhor que um diff ilegível.
    fail('Roboto não encontrada em ${arquivo.path} — defina FLUTTER_ROOT');
  }

  final loader = FontLoader('Roboto')
    ..addFont(arquivo.readAsBytes().then((b) => ByteData.view(b.buffer)));
  await loader.load();
}
