class GlobalState {
  static final GlobalState _instance = GlobalState._internal();

  factory GlobalState() {
    return _instance;
  }

  GlobalState._internal();

  List<int> idLojas = [];
  int? idCliente;

  int get firstIdLoja => idLojas.isNotEmpty ? idLojas.first : 0;
}
