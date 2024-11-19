import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ext_rw/src/api_client/message/field_id.dart';
import 'package:ext_rw/src/api_client/message/message.dart';
import 'package:ext_rw/src/api_client/message/parse_data.dart';
import 'package:ext_rw/src/api_client/message/field_data.dart';
import 'package:ext_rw/src/api_client/message/field_kind.dart';
import 'package:ext_rw/src/api_client/message/field_size.dart';
import 'package:ext_rw/src/api_client/message/field_syn.dart';
import 'package:ext_rw/src/api_client/message/parse_id.dart';
import 'package:ext_rw/src/api_client/message/parse_kind.dart';
import 'package:ext_rw/src/api_client/message/message_parse.dart';
import 'package:ext_rw/src/api_client/message/parse_size.dart';
import 'package:ext_rw/src/api_client/message/parse_syn.dart';
import 'package:ext_rw/src/api_client/query/api_query_type.dart';
import 'package:ext_rw/src/api_client/address/api_address.dart';
import 'package:ext_rw/src/api_client/reply/api_reply.dart';
import 'package:ext_rw/src/api_client/message/message_build.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hmi_core/hmi_core_option.dart';
import 'package:hmi_core/hmi_core_result.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/io.dart';
///
/// Performs the request to the API server
class ApiRequest {
  static final _log = const Log('ApiRequest')..level = LogLevel.info;
  final ApiAddress _address;
  final String _authToken;
  final ApiQueryType _query;
  final Duration _timeout;
  final Duration _connectTimeout;
  final bool _debug;
  final Map<int, Completer<Result<ApiReply, Failure>>> _queries = {};
  Option<Message> _message = None();
  int _id = 0;
  ///
  /// Request to the API server
  /// - authToken
  /// - address - IP and port of the API server
  /// - query - paload data to be sent to the API server, containing specific kind of API query
  /// - timeout
  /// - connectTimeout
  ApiRequest({
    required String authToken,
    required ApiAddress address,
    required ApiQueryType query,
    Duration timeout = const Duration(milliseconds: 3000),
    Duration connectTimeout = const Duration(milliseconds: 256),
    bool debug = false,
  }) :
    _authToken = authToken,
    _address = address,
    _query = query,
    _timeout = timeout,
    _connectTimeout = connectTimeout,
    _debug = debug;
  ///
  /// Conecting the socket, setup the message listener
  Future<Result<(), Failure>> _connect() async {
    if (_message.isNone()) {
      await Socket
        .connect(_address.host, _address.port, timeout: _connectTimeout)
        .then(
          (socket) async {
            socket.setOption(SocketOption.tcpNoDelay, true);
            _message = Some(Message(socket));
          },
          onError: (err) {
            return Err(Failure(message: 'ApiRequest._fetchSocket | Connection error: $err', stackTrace: StackTrace.current));
          },
        );
    }
    if (_message case Some(value: final message)) {
      message.stream.listen(
        (event) {
          final (FieldId id, FieldKind kind, Bytes bytes) = event;
          _log.debug('.listen.onData | Event | id: $id,  kind: $kind,  bytes: $bytes');
          if (_queries.containsKey(id.id)) {
            final query = _queries[id.id];
            if (query != null) {
              query.complete(
                Ok(ApiReply.fromJson(
                  utf8.decode(bytes),
                )),
              );
              _queries.remove(id.id);
            }
          } else {
            _log.error('.listen.onData | id \'${id.id}\' - not found');
          }
        },
        onError: (err) {
          _log.error('.listen.onError | Error: $err');
          message.close();
          _message = None();
        },
        onDone: () {
          _log.debug('.listen.onDone | Done');
          message.close();
          _message = None();
        },
      );
    }
    return Ok(());
  }
  ///
  String get authToken => _authToken;
  ///
  /// Sends created request to the remote
  /// - returns reply if exists
  Future<Result<ApiReply, Failure>> fetch() async {
    final query = _query.buildJson(authToken: _authToken, debug: _debug);
    final bytes = utf8.encode(query);
    if (kIsWeb) {
      return _fetchWebSocket(bytes);
    } else {
      return _fetchSocket(bytes);
    }
  }
  ///
  /// Sends created request with new query to the remote
  /// - returns reply if exists
  Future<Result<ApiReply, Failure>> fetchWith(ApiQueryType query) async {
    final queryJson = query.buildJson(authToken: _authToken, debug: _debug);
    final bytes = utf8.encode(queryJson);
    if (kIsWeb) {
      return _fetchWebSocket(bytes);
    } else {
      return _fetchSocket(bytes);
    }
  }
  ///
  /// Fetching on tcp socket
  Future<Result<ApiReply, Failure>> _fetchSocket(Bytes bytes) async {
    switch (await _connect()) {
      case Ok<(), Failure>():
        _id++;
        if (!_queries.containsKey(_id)) {
          _log.debug('._fetchSocket | id: \'$_id\',  sql: $bytes');
          final Completer<Result<ApiReply, Failure>> completer = Completer();
          _queries[_id] = completer;
          if (_message case Some(value: final message)) {
            message.add(_id, bytes);
            return completer.future.timeout(_timeout, onTimeout: () {
              return Err(Failure(message: '._fetchSocket | Timeout ($_timeout) expired', stackTrace: StackTrace.current));
            });
          } else {
            return Err(Failure(message: '._fetchSocket | Not ready _message', stackTrace: StackTrace.current));
          }
        }
        return Err(Failure(message: '._fetchSocket | Duplicated _id \'$_id\'', stackTrace: StackTrace.current));
      case Err<(), Failure>(: final error):
        return Err(Failure(message: '._fetchSocket | Connection error $error', stackTrace: StackTrace.current));
    }
  }
  ///
  /// Fetching on web socket
  Future<Result<ApiReply, Failure>> _fetchWebSocket(Bytes bytes) {
    return WebSocket.connect('ws://${_address.host}:${_address.port}')
      .then((wSocket) async {
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
      })
      .catchError((error) {
          return Err<ApiReply, Failure>(
            Failure(
              message: '.fetch | web socket error: $error', 
              stackTrace: StackTrace.current,
            ),
          );
      });
  }
  ///
  Future<Result<List<int>, Failure>> _readWeb(WebSocket socket) async {
    try {
      List<int> message = [];
      final subscription = socket
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
      _log.warning('._read | socket error: $error');
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
  /// Returns MessageParse new instance
  ParseData resetParseMessage() {
    return ParseData(
      field: ParseSize(
        size: FieldSize.def(),
        field: ParseKind(
          field: ParseId(
            id: FieldId.def(),
            field: ParseSyn.def(),
          ),
        ),
      ),
    );
  }
  ///
  /// Sends bytes over WEB socket
  Future<Result<bool, Failure>> _sendWeb(WebSocket socket, Bytes bytes) async {
    final message = MessageBuild(
      syn: FieldSyn.def(),
      id: FieldId.def(),
      kind: FieldKind.string,
      size: FieldSize.def(),
      data: FieldData([]),
    );
    try {
      socket.add(message.build(bytes));
      return Future.value(const Ok(true));
    } catch (error) {
      _log.warning('._send | Web socket error: $error');
      return Err(
        Failure.connection(
          message: '._send | Web socket error: $error', 
          stackTrace: StackTrace.current,
        ),
      );
    }
  }
  ///
  /// Closes the socket
  Future<void> _closeSocketWeb(WebSocket? socket) async {
    try {
      socket?.close();
      // socket?.destroy();
    } catch (error) {
      _log.warning('[.close] error: $error');
    }
  }  
}