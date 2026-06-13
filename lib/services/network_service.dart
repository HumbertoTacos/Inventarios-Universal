import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  bool isOffline = false;

  // Stream para que la UI reaccione en tiempo real
  Stream<bool> get onOfflineChange => _connectivity.onConnectivityChanged.map((results) {
    // Si la lista solo contiene 'none', estamos fuera de línea
    isOffline = results.every((result) => result == ConnectivityResult.none);
    return isOffline;
  });

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    isOffline = results.every((result) => result == ConnectivityResult.none);
  }
}
