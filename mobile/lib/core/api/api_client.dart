import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';

// Resolved automatically per platform; override at build/run time for a
// physical device or LAN host with:
//   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000
const String _overrideBaseUrl = String.fromEnvironment('API_BASE_URL');

String _resolveBaseUrl() {
  if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
  if (kIsWeb) return 'http://localhost:3000';
  // Android emulator's special alias for the host machine's localhost
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
  // iOS simulator shares the host's network, so localhost works directly
  return 'http://localhost:3000';
}

final String kBaseUrl = _resolveBaseUrl();

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static Future<void> init() async {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  // ── Auth ────────────────────────────────────────────────────
  static Future<Response> login(String identifier, String password) =>
      _dio.post('/auth/login', data: {'identifier': identifier, 'password': password});

  static Future<Response> mfaVerify(String preAuthToken, String code) =>
      _dio.post('/auth/mfa/verify', data: {'pre_auth_token': preAuthToken, 'code': code});

  static Future<Response> getMe() => _dio.get('/auth/me');

  static Future<Response> signup(Map<String, dynamic> data) =>
      _dio.post('/auth/signup', data: data);

  static Future<Response> logout() => _dio.post('/auth/logout');

  static Future<Response> setLocale(String locale) =>
      _dio.patch('/auth/me/locale', data: {'locale': locale});

  static Future<Response> updateProfile(Map<String, dynamic> data) =>
      _dio.patch('/auth/me/profile', data: data);

  static Future<Response> updateAvatar(String mediaId) =>
      _dio.patch('/auth/me/avatar', data: {'media_id': mediaId});

  static Future<Response> changePassword(String currentPassword, String newPassword) =>
      _dio.patch('/auth/me/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

  static Future<Response> updateSettings(Map<String, dynamic> data) =>
      _dio.patch('/auth/me/settings', data: data);

  // ── Users ───────────────────────────────────────────────────
  static Future<Response> lookupUser(String identifier) =>
      _dio.get('/users/lookup', queryParameters: {'identifier': identifier});

  // ── Conversations ────────────────────────────────────────────
  static Future<Response> getConversations({bool archived = false}) =>
      _dio.get('/conversations', queryParameters: archived ? {'archived': true} : {});

  static Future<Response> createConversation(String type, List<String> memberIds, {String? name}) =>
      _dio.post('/conversations', data: {'type': type, 'member_ids': memberIds, 'name': name});

  static Future<Response> archiveConversation(String id) =>
      _dio.patch('/conversations/$id/archive');

  static Future<Response> unarchiveConversation(String id) =>
      _dio.patch('/conversations/$id/unarchive');

  static Future<Response> muteConversation(String id, String duration) =>
      _dio.patch('/conversations/$id/mute', data: {'duration': duration});

  static Future<Response> unmuteConversation(String id) =>
      _dio.patch('/conversations/$id/unmute');

  static Future<Response> setDisappearing(String id, String? duration) =>
      _dio.patch('/conversations/$id/disappearing', data: {'duration': duration});

  // ── Scheduled messages ───────────────────────────────────────
  static Future<Response> scheduleMessage(String conversationId, Map<String, dynamic> payload) =>
      _dio.post('/conversations/$conversationId/scheduled-messages', data: payload);

  static Future<Response> getScheduledMessages(String conversationId) =>
      _dio.get('/conversations/$conversationId/scheduled-messages');

  static Future<Response> cancelScheduledMessage(String conversationId, String scheduledId) =>
      _dio.delete('/conversations/$conversationId/scheduled-messages/$scheduledId');

  // ── Messages ─────────────────────────────────────────────────
  static Future<Response> getMessages(String convId, {String? before}) =>
      _dio.get('/conversations/$convId/messages',
          queryParameters: {'limit': 50, if (before != null) 'before': before});

  // ── Media ────────────────────────────────────────────────────
  static Future<Response> uploadMedia(String filePath, String mimeType) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, contentType:
          DioMediaType.parse(mimeType)),
    });
    return _dio.post('/media/upload', data: form);
  }

  static Future<Response> getMediaUrl(String mediaId) =>
      _dio.get('/media/$mediaId/url');

  // ── Calls ─────────────────────────────────────────────────────
  static Future<Response> getTurnCredentials() => _dio.get('/calls/turn-credentials');

  static Future<Response> getCallHistory({String? before}) =>
      _dio.get('/calls/history', queryParameters: {if (before != null) 'before': before});

  // ── Notifications ────────────────────────────────────────────
  static Future<Response> getNotifications() =>
      _dio.get('/notifications', queryParameters: {'limit': 20});

  static Future<Response> markNotificationRead(String id) =>
      _dio.patch('/notifications/$id/read');

  // ── Search ───────────────────────────────────────────────────
  static Future<Response> searchMessages(Map<String, dynamic> params) =>
      _dio.get('/search/messages', queryParameters: params);
}
