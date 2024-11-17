import 'dart:async';
import 'dart:io';

import 'package:ext_rw/src/api_client/message/field_data.dart';
import 'package:ext_rw/src/api_client/message/field_id.dart';
import 'package:ext_rw/src/api_client/message/field_kind.dart';
import 'package:ext_rw/src/api_client/message/field_size.dart';
import 'package:ext_rw/src/api_client/message/field_syn.dart';
import 'package:ext_rw/src/api_client/message/message_build.dart';
import 'package:ext_rw/src/api_client/message/message_parse.dart';
import 'package:ext_rw/src/api_client/message/parse_data.dart';
import 'package:ext_rw/src/api_client/message/parse_id.dart';
import 'package:ext_rw/src/api_client/message/parse_kind.dart';
import 'package:ext_rw/src/api_client/message/parse_size.dart';
import 'package:ext_rw/src/api_client/message/parse_syn.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_option.dart';
///
///
class Message {
  final _log = Log('Message');
  final StreamController<(FieldId, FieldKind, Bytes)> _controller = StreamController();
  final Socket _socket;
  late StreamSubscription? _subscription;
  final MessageBuild _messageBuild = MessageBuild(
    syn: FieldSyn.def(),
    id: FieldId.def(),
    kind: FieldKind.string,
    size: FieldSize.def(),
    data: FieldData([]),
  );
  ///
  ///
  Message(Socket socket) :
    _socket = socket;
  ///
  ///
  Stream<(FieldId, FieldKind, Bytes)> get stream {
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
    _subscription = _socket.listen(
      (Bytes event) {
        _log.debug('.listen.onData | Event: $event');
        switch (message.parse(event)) {
          case Some<(FieldId, FieldKind, FieldSize, Bytes)>(value: (final id, final kind, final size, final bytes)):
            _log.debug('.listen.onData | id: $id,  kind: $kind,  size: $size, bytes: $bytes');
            _controller.add((id, kind, bytes));
          case None():
            _log.debug('.listen.onData | None');
        }
      },
      onError: (err) {
        _log.error('.listen.onError | Error: $err');
        _subscription?.cancel();
        _socket.close();
      },
      onDone: () {
        _log.debug('.listen.onDone | Done');
        _subscription?.cancel();
        _socket.close();
      },
    );
    return _controller.stream;
  }
  ///
  ///
  void add(id, Bytes bytes) {
    final message = _messageBuild.build(bytes, id: id);
    _socket.add(message);
  }
  ///
  ///
  Future close() async {
    await _subscription?.cancel();
    return _socket.close();
  }
}
