import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/socket/socket_service.dart';
import '../../core/storage/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = true;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      try {
        final res = await ApiClient.getMe();
        _user = res.data['user'];
        SocketService.connect(token);
      } catch (_) {
        await SecureStorage.deleteToken();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> completeLogin(String token) async {
    await SecureStorage.saveToken(token);
    final res = await ApiClient.getMe();
    _user = res.data['user'];
    SocketService.connect(token);
    notifyListeners();
  }

  // Merges a partial update (e.g. the response from a profile/avatar/settings
  // PATCH) into the in-memory user map so every screen reading
  // context.watch<AuthProvider>().user reflects the change immediately,
  // without waiting for a full re-fetch.
  void updateUser(Map<String, dynamic> patch) {
    if (_user == null) return;
    _user = {..._user!, ...patch};
    notifyListeners();
  }

  Future<void> logout() async {
    try { await ApiClient.logout(); } catch (_) {}
    await SecureStorage.deleteToken();
    SocketService.disconnect();
    _user = null;
    notifyListeners();
  }
}
