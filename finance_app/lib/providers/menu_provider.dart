import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Se o menu lateral fixo está recolhido só aos ícones.
///
/// **Precisa ser global, e não estado de tela.** A `MolduraMenu` é montada por
/// cada página, então um `StatefulWidget` guardaria a escolha só até a próxima
/// navegação — o menu voltaria a expandir toda vez que se trocasse de tela.
///
/// Persiste no `SharedPreferences` pelo mesmo motivo do tema: é preferência de
/// quem usa, não estado de sessão. Vale só para o menu **fixo** — como gaveta
/// não há o que recolher, e quem consulta isso é a própria moldura.
class MenuProvider with ChangeNotifier {
  static const _chave = 'menu_colapsado';

  bool _colapsado = false;

  bool get colapsado => _colapsado;

  MenuProvider() {
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    _colapsado = prefs.getBool(_chave) ?? false;
    notifyListeners();
  }

  Future<void> alternar() async {
    _colapsado = !_colapsado;
    notifyListeners();

    // Avisa primeiro e grava depois: o menu responde ao toque no mesmo frame, e
    // uma falha de escrita não pode travar a animação.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave, _colapsado);
  }
}
