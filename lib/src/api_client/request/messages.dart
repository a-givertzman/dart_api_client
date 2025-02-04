import 'dart:async';
import 'dart:io';

import 'package:ext_rw/src/api_client/address/api_address.dart';
import 'package:ext_rw/src/api_client/message/message.dart';
import 'package:ext_rw/src/api_client/message/message_parse.dart';
import 'package:ext_rw/src/api_client/reply/api_reply.dart';
import 'package:ext_rw/src/api_client/request/arc_message.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_option.dart';
import 'package:hmi_core/hmi_core_result.dart';

///
/// Provide multiple requests via [ArcMessage] - a part of `ApiRequest`
/// - Can be fetched multiple times
/// - Keeps socket connection opened if `query` has keepAlive = true
class Messages {
  static final _log = const Log('Messages');//..level = LogLevel.debug;
  final List<ArcMessage> _messages = [];
  final ApiAddress _address;
  final Duration _timeout;
  Option<Completer<Result<ArcMessage, Failure>>> _connection = None();
  ///
  /// 
  /// Provide multiple requests via [ArcMessage]
  /// - address - IP and port of the API server
  /// - timeout - time to wait read, write & connection until timeout error, default - 3 sec
  Messages({
    required ApiAddress address,
    Duration timeout = const Duration(milliseconds: 3000),
  }):
    _address = address,
    _timeout = timeout;
  ///
  /// Sends `bytes` to the remote
  /// - `id` - integer id unique withing connection
  /// - `keepAlive` - keeping socket connection opened if `true`
  /// - Returns reply or error
  Future<Result<ApiReply, Failure>> fetch(int id, Bytes bytes, bool keepAlive) async {
    int index = 0;
    while (index < _messages.length) {
      final message = _messages.elementAt(index);
      if (message.done) {
        // _log.debug('.fetch | Removing done message: $message');
        _messages.remove(message);
      } else if (message.keep) {
        // _log.debug('.fetch | Found message: $message');
        return message.fetch(id, bytes);
      } else {
        index++;
      }
    }
    return _connect(id, bytes, keepAlive).then(
        (result) {
          switch (result) {
            case Ok<ArcMessage, Failure>(value: final message):
              return message.fetch(id, bytes);
            case Err<ArcMessage, Failure>(: final error):
              return Err<ApiReply, Failure>(Failure(message: 'Messages.fetch | Error: $error', stackTrace: StackTrace.current));
          }
        },
        onError: (error) {
            return Err<ApiReply, Failure>(Failure(message: 'Messages.fetch | Error: $error', stackTrace: StackTrace.current));
        },
      );
  }
  ///
  /// Returns cached [ArcMessage] if exists or conect new one
  Future<Result<ArcMessage, Failure>> _connect(int id, Bytes bytes, bool keepAlive) {
    // final connection = _connection;
    switch (_connection) {
      // default:
      case Some<Completer<Result<ArcMessage, Failure>>>(value: final connection):
        // _log.debug('._connect | Connection awaiting...');
        return connection.future;
      case None():
        // _log.debug('._connect | Connecting...');
        final connection = Completer<Result<ArcMessage, Failure>>();
        _connection = Some(connection);
        _socket(id, bytes, keepAlive).then(
          (result) {
            // _log.debug('._connect | New connection result: $result');
            switch (result) {
              case Ok<ArcMessage, Failure>(value: final message):
                // _log.debug('._connect | connected');
                connection.complete(Ok(message));
                _connection = None();
              case Err<ArcMessage, Failure>(: final error):
                connection.complete(
                  Err(Failure(message: 'Messages._connect | Error: $error', stackTrace: StackTrace.current)),
                );
                _connection = None();
            }
          },
          onError: (error) {
            _log.warning('._connect | Error: $error');
            connection.complete(
              Err(Failure(message: 'Messages._connect | Error: $error', stackTrace: StackTrace.current)),
            );
            _connection = None();
          },
        );
        return connection.future;
    }
  }
  ///
  /// Returns new connected [ArcMessage] or error
  Future<Result<ArcMessage, Failure>> _socket(int id, Bytes bytes, bool keepAlive) {
    return Socket
      .connect(_address.host, _address.port, timeout: _timeout)
      .then(
        (socket) {
          // _log.debug('._socket | connected');
          socket.setOption(SocketOption.tcpNoDelay, true);
          final message = ArcMessage(Message(socket), keepAlive, timeout: _timeout);
          _messages.add(message);
          // _log.warning('._socket | _messages $_messages');
          return Ok(message);
        },
        onError: (err) {
          _log.warning('._socket | Error $err');
          return Err<ArcMessage, Failure>(Failure(message: 'Messages._socket | Connection error: $err', stackTrace: StackTrace.current));
        },
      );
  }
  ///
  /// Closes connection
  Future<void> close() {
    if (_connection case Some<Completer<Result<ArcMessage, Failure>>>(value: final connection)) {
      connection.complete(
        Err(Failure(message: 'Messages.close | Connection closed', stackTrace: StackTrace.current)),
      );
    }
    return Future.wait(_messages.map((msg) {
      return msg.close();
    }));
  }
}
