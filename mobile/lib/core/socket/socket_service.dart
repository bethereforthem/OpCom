import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_client.dart';

class SocketService {
  static io.Socket? _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static void connect(String token) {
    _socket?.disconnect();
    _socket = io.io(kBaseUrl, io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .build());

    _socket!.onConnect((_) => print('[Socket] Connected'));
    _socket!.onDisconnect((_) => print('[Socket] Disconnected'));
    _socket!.onConnectError((e) => print('[Socket] Error: $e'));
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  static void off(String event) {
    _socket?.off(event);
  }

  static void emit(String event, dynamic data, [Function(dynamic)? ack]) {
    if (ack != null) {
      _socket?.emitWithAck(event, data, ack: ack);
    } else {
      _socket?.emit(event, data);
    }
  }
}
