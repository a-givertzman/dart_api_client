import 'package:ext_rw/src/api_client/message/field_id.dart';
import 'package:ext_rw/src/api_client/message/message_parse.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_option.dart';
import 'package:hmi_core/hmi_core_result.dart';
///
/// Extracting `Id` part from the input bytes
class ParseId implements MessageParse<Bytes, Option<(FieldId, Bytes)>> {
  final _log = const Log('ParseId');
  final MessageParse<Bytes, Option<Bytes>> _field;
  final FieldId _confId;
  Bytes _buf = [];
  int? _id;
  ///
  /// # Returns ParseId new instance
  /// - **in case of Receiving**
  ///   - [field] - is [ParseSyn]
  ParseId({
    required FieldId id,
    required MessageParse<Bytes, Option<Bytes>> field,
  }) :
    _confId = id,
    _field = field;
  ///
  /// Returns message `Id` extracted from the input and the remaining bytes
  /// - [input] - input bytes, can be passed multiple times
  /// - if `Id` is not detected: returns None
  /// - if `Id` is detected: returns `Id` and all bytes following the `Id`
  @override
  Option<(FieldId, Bytes)> parse(Bytes input) {
    final id_ = _id;
    if (id_ == null) {
      _buf = [..._buf, ...input];
      switch (_field.parse(_buf)) {
        case Some(value: Bytes bytes):
          if (bytes.length >= _confId.len) {
            return switch (_confId.fromBytes(bytes.sublist(0, _confId.len))) {
              Ok(value: final id) => () {
                _id = id;
                _log.debug('.parse | bytes: $bytes');
                return Some((FieldId(id), bytes.sublist(_confId.len)));
              }() as Option<(FieldId, Bytes)>,
              Err() => () {
                _buf = bytes;
                return None();
              }(),
            };
          } else {
            _buf = bytes;
            return None();
          }
        case None():
          return None();
      }
    } else {
      return Some((FieldId(id_), input));
    }
  }
}
