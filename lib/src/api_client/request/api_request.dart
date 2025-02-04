import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ext_rw/src/api_client/message/field_id.dart';
import 'package:ext_rw/src/api_client/message/field_data.dart';
import 'package:ext_rw/src/api_client/message/field_kind.dart';
import 'package:ext_rw/src/api_client/message/field_size.dart';
import 'package:ext_rw/src/api_client/message/field_syn.dart';
import 'package:ext_rw/src/api_client/message/message_parse.dart';
import 'package:ext_rw/src/api_client/query/api_query_type.dart';
import 'package:ext_rw/src/api_client/address/api_address.dart';
import 'package:ext_rw/src/api_client/reply/api_reply.dart';
import 'package:ext_rw/src/api_client/message/message_build.dart';
import 'package:ext_rw/src/api_client/request/messages.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hmi_core/hmi_core_result.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/io.dart';
///
/// Performs the request(s) to the API server
/// - `ApiRequest.keep` can be fetched multiple times, call `close()` at the end
class ApiRequest {
  static final _log = const Log('ApiRequest');
  final ApiAddress _address;
  final String _authToken;
  final ApiQueryType _query;
  final Duration _timeout;
  final bool _keep;
  final bool _debug;
  final Messages _messages;
  int _id = 0;
  ///
  /// Single request to the API server
  /// - Can be fetched only once
  /// - authToken - authentication parameter, dipends on authentication kind
  /// - address - IP and port of the API server
  /// - query - paload data to be sent to the API server, containing specific kind of API query
  /// - timeout - time to wait read, write & connection until timeout error, default - 3 sec
  ApiRequest({
    required String authToken,
    required ApiAddress address,
    required ApiQueryType query,
    Duration timeout = const Duration(milliseconds: 3000),
    bool debug = false,
  }) :
    _authToken = authToken,
    _address = address,
    _query = query,
    _timeout = timeout,
    _keep = false,
    _debug = debug,
    _messages = Messages(address: address, timeout: timeout);
  ///
  /// Multiple requests to the API server
  /// - Can be fetched multiple times
  /// - Must be closed by calling `close()` at the end
  /// - authToken - authentication parameter, dipends on authentication kind
  /// - address - IP and port of the API server
  /// - query - paload data to be sent to the API server, containing specific kind of API query
  /// - timeout - time to wait read, write & connection until timeout error, default - 3 sec
  ApiRequest.keep({
    required String authToken,
    required ApiAddress address,
    required ApiQueryType query,
    Duration timeout = const Duration(milliseconds: 3000),
    bool debug = false,
  }) :
    _authToken = authToken,
    _address = address,
    _query = query,
    _timeout = timeout,
    _keep = true,
    _debug = debug,
    _messages = Messages(address: address, timeout: timeout);
  ///
  /// Returns specified authToken
  String get authToken => _authToken;
  ///
  /// Sends created request to the remote
  /// - Returns reply or error
  Future<Result<ApiReply, Failure>> fetch() async {
    final queryJson = _query.buildJson(authToken: _authToken, debug: _debug, keep: _keep);
    final bytes = utf8.encode(queryJson);
    _log.info('.fetch | platform: ${kIsWeb ? 'Web' : 'NonWeb'}');
    if (kIsWeb) {
      return _fetchWebSocket(bytes);
    } else {
      return _fetchSocket(bytes);
    }
  }
  ///
  /// Sends specified `query` to the remote
  /// - Returns reply or error
  Future<Result<ApiReply, Failure>> fetchWith(ApiQueryType query) async {
    final queryJson = query.buildJson(authToken: _authToken, debug: _debug, keep: _keep);
    final bytes = utf8.encode(queryJson);
    _log.info('.fetchWith | platform: ${kIsWeb ? 'Web' : 'NonWeb'}');
    if (kIsWeb) {
      return _fetchWebSocket(bytes);
    } else {
      return _fetchSocket(bytes);
    }
  }
  ///
  /// Fetching on tcp socket
  Future<Result<ApiReply, Failure>> _fetchSocket(Bytes bytes) async {
    _id++;
    return _messages.fetch(_id, bytes, _keep).then(
      (value) {
        if (!_keep) {
          _messages.close();
        }
        return value;
      },
      onError: (error) => error,
    );
  }
  ///
  /// Fetching on web socket
  Future<Result<ApiReply, Failure>> _fetchWebSocket(Bytes bytes) async {
    return Future.microtask(() async {
      final wSocket = WebSocketChannel.connect(Uri.parse('wss://${_address.host}:${_address.port}'));
      _log.warn('._fetchWebSocket | wSocket connecting to ${_address.host}:${_address.port}...');
      try {
        await wSocket.ready;
      } on SocketException catch (err) {
        _log.warn('._fetchWebSocket | wSocket connection error $err');
        return Err(Failure(message: 'ApiRequest._fetchWebSocket | Connection error $err', stackTrace: StackTrace.current));
      } on WebSocketChannelException catch (err) {
        _log.warn('._fetchWebSocket | wSocket connection error $err');
        return Err(Failure(message: 'ApiRequest._fetchWebSocket | Connection error $err', stackTrace: StackTrace.current));
      }
      _log.warn('._fetchWebSocket | wSocket connected to: ${wSocket}');
      return _sendWeb(wSocket, bytes)
        .then((result) {
          return switch(result) {
            Ok() => _readWeb(wSocket)
              .then((result) {
                final Result<ApiReply, Failure> r = switch(result) {
                  Ok(:final value) => Ok(
                    ApiReply.fromJson(
                      utf8.decode(value),
                    ),
                  ),
                  Err(:final error) => Err(error),
                };
                return r;
              }), 
            Err(:final error) => Future<Result<ApiReply, Failure>>.value(
                Err(error),
              ),
          };
        });

    });
  }
  ///
  /// Reads bytes from web socket
  Future<Result<List<int>, Failure>> _readWeb(WebSocketChannel socket) async {
    try {
      List<int> message = [];
      final subscription = socket.stream
        .timeout(
          _timeout,
          onTimeout: (sink) {
            sink.close();
          },
        )
        .listen((event) {
          message.addAll(event);
        });
      await subscription.asFuture();
      // _log.fine('._read | socket message: $message');
      _closeSocketWeb(socket);
      return Ok(message);
    } catch (error) {
      _log.warn('._read | socket error: $error');
      await _closeSocketWeb(socket);
      return Err(
        Failure.connection(
          message: '._read | socket error: $error', 
          stackTrace: StackTrace.current,
        ),
      );
    }
  }
  ///
  /// Sends bytes over WEB socket
  Future<Result<bool, Failure>> _sendWeb(WebSocketChannel socket, Bytes bytes) async {
    // final message = MessageBuild(
    //   syn: FieldSyn.def(),
    //   id: FieldId.def(),
    //   kind: FieldKind.bytes,
    //   size: FieldSize.def(),
    //   data: FieldData([]),
    // );
    try {
      _id++;
      // final msgBytes = message.build(bytes, id: _id);
      // _log.info('._send | Web socket bytes: ${msgBytes.sublist(0, 16)}');
      socket.sink.add(bytes);
      return Future.value(const Ok(true));
    } catch (error) {
      _log.warn('._send | Web socket error: $error');
      return Err(
        Failure.connection(
          message: '._send | Web socket error: $error', 
          stackTrace: StackTrace.current,
        ),
      );
    }
  }
  ///
  /// Closes web socket
  Future<void> _closeSocketWeb(WebSocketChannel? socket) async {
    try {
      socket?.sink.close();
    } catch (error) {
      _log.warn('[.close] error: $error');
    }
  }
  ///
  /// Closes connection
  Future<void> close() {
    return _messages.close();
  }
}
