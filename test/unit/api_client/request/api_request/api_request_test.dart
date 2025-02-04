import 'dart:io';

import 'package:ext_rw/ext_rw.dart';
import 'package:ext_rw/src/api_client/message/field_data.dart';
import 'package:ext_rw/src/api_client/message/field_id.dart';
import 'package:ext_rw/src/api_client/message/field_syn.dart';
import 'package:ext_rw/src/api_client/message/message_build.dart';
import 'package:ext_rw/src/api_client/message/message_parse.dart';
import 'package:ext_rw/src/api_client/message/parse_data.dart';
import 'package:ext_rw/src/api_client/message/field_kind.dart';
import 'package:ext_rw/src/api_client/message/field_size.dart';
import 'package:ext_rw/src/api_client/message/parse_id.dart';
import 'package:ext_rw/src/api_client/message/parse_kind.dart';
import 'package:ext_rw/src/api_client/message/parse_size.dart';
import 'package:ext_rw/src/api_client/message/parse_syn.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_option.dart';

import 'fake_query_type.dart';
///
/// setup constants
const int syn = 22;
const restart = true;
const keepGo = false;
///
/// Fake socket server
class FakeServer {
  final _log = Log('Server');
  final String host;
  final int port;
  ///
  /// Fake socket server
  FakeServer(this.host, this.port);
  ///
  /// Starting server on the specified [host]:[port] address
  Future start() {
    _log.debug('.start | Binding SocketServer on: $host:$port}');
    return ServerSocket.bind(host, port).then(
      (server) {
        _log.debug('.bind | SocketServer ready on: ${server.address.host}:${server.port}');
        server.listen(
          (socket) {
            _log.debug('.listen | Incoming connection from: ${socket.address.host}:${socket.port}');
            int lastId = -1;
            final message = ParseData(
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
            final messageBuild = MessageBuild(
              syn: FieldSyn.def(),
              id: FieldId.def(),
              kind: FieldKind.string,
              size: FieldSize.def(),
              data: FieldData([]),
            );
            socket.listen(
              (event) {
                // _log.debug('.listen.onData | event (${event.length}): $event');
                Uint8List? input = event;
                bool isSome = true;
                while (isSome) {
                  // _log.debug('.listen.onData | input (${input?.length}): $input');
                  switch (message.parse(input)) {
                    case Some<(FieldId, FieldKind, FieldSize, Bytes)>(value: (final id, final kind, final size, final bytes)):
                      _log.debug('.listen.onData | Parsed | id: $id,  kind: $kind,  size: $size, bytes: $bytes');
                      lastId = id.id;
                      Future.delayed(Duration(milliseconds: 500), () {
                        final reply = messageBuild.build(bytes, id: id.id);
                        try {
                          socket.add(reply);
                        } catch (err) {
                          _log.debug('.listen.onData | Send error: $err');
                        }
                      });
                      input = null;
                    case None():
                      _log.debug('.listen.onData | Parsed | None');
                      isSome = false;
                  }
                }
              },
              onError: (err) {
                _log.error('.listen.onError | lastId: $lastId,  Error: $err');
              },
              onDone: () {
                _log.debug('.listen.onDone | lastId: $lastId, Done');
              },
            );
          },
          onError: (err) {
            _log.error('.listen.onError | Error: $err');
            // server.close();
          },
          onDone: () {
            _log.debug('.listen.onDone | Done');
            server.close();
          },
        );
      },
      onError: (err) {
        _log.error('.bind.onError | Error: $err');
      },
    );
  }
}
///
/// Testing [ParseData].parse
void main() {
  Log.initialize(level: LogLevel.all);
  final log = Log('Test:ApiRequest');
  group('ApiRequest.fetch', () {
    ///
    ///
    test('with keepAlive', () async {
      final (host, port) = ('0.0.0.0', 5061);
      await FakeServer(host, port).start();
      List<Future> replies = [];
      final time = Stopwatch()..start();
      final request = ApiRequest.keep(
        address: ApiAddress(host: host, port: port),
        authToken: '***token***',
        query: FakeApiQueryType(valid: true, query: ''),
      );
      for (final i in Iterable.generate(3)) {
        final query = FakeApiQueryType(valid: true, query: 'Client.Request$i');
        final reply = request.fetchWith(query).then(
          (reply) {
            log.info('.request.fetch | reply: $reply');
            // log.info('.request.fetch | reply text: ${String.fromCharCodes(reply)}');
          },
          onError: (err) {
            log.error('.request.fetch.onError | Error: $err');
          },
        );
        replies.add(reply);
        await Future.delayed(Duration(milliseconds: 10));
      }
      await Future.wait(replies);
      log.info('.request | All (${replies.length}) replies finished');
      log.info('.request | Elapsed: ${time.elapsed}');
    });
    test('without keepAlive', () async {
      final (host, port) = ('0.0.0.0', 5061);
      await FakeServer(host, port).start();
      List<Future> replies = [];
      final time = Stopwatch()..start();
      final request = ApiRequest(
        address: ApiAddress(host: host, port: port),
        authToken: '***token***',
        query: FakeApiQueryType(valid: true, query: ''),
        
      );
      for (final i in Iterable.generate(3)) {
        final query = FakeApiQueryType(valid: true, query: 'Client.Request$i');
        final reply = request.fetchWith(query).then(
          (reply) {
            log.info('.request.fetch | reply: $reply');
            // log.info('.request.fetch | reply text: ${String.fromCharCodes(reply)}');
          },
          onError: (err) {
            log.error('.request.fetch.onError | Error: $err');
          },
        );
        replies.add(reply);
        await Future.delayed(Duration(milliseconds: 10));
      }
      await Future.wait(replies);
      log.info('.request | All (${replies.length}) replies finished');
      log.info('.request | Elapsed: ${time.elapsed}');
    });
  });
}
