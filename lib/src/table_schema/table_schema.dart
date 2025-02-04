import 'package:ext_rw/ext_rw.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_result.dart';

///
/// A collection of the SchameEntry, 
/// abstruction on the SQL table rows
class TableSchema<T extends SchemaEntryAbstract, P> implements TableSchemaAbstract<T, P> {
  late final Log _log;
  final List<Field<T>> _fields;
  final Map<String, T> _entries = {};
  final SchemaRead<T, P> _read;
  final SchemaWrite<T> _write;
  ///
  /// A collection of the SchameEntry, 
  /// abstruction on the SQL table rows
  /// - [keys] - list of table field names
  TableSchema({
    required List<Field<T>> fields,
    SchemaRead<T, P> read = const SchemaRead.empty(),
    SchemaWrite<T> write = const SchemaWrite.empty(),
  }) :
    _fields = fields,
    _read = read,
    _write = write {
      _log = Log("$runtimeType")..level = LogLevel.info;
    }
  ///
  /// Returns a list of table field names
  @override
  List<Field<T>> get fields {
    return _fields;
  }
  ///
  /// Returns a list of table field keys
  @override
  List<String> get keys {
    return _fields.map((field) => field.key).toList();
  }
  //
  //
  @override
  Map<String, T> get entries => _entries;
  ///
  /// Fetchs data with new sql built from [values]
  @override
  Future<Result<List<T>, Failure>> fetch(P? params) async {
    return _read.fetch(params: params).then(
      (result) {
        _log.debug('.fetch | result: $result');
        return switch(result) {
          Ok<List<T>, Failure>(value: final entries) => () {
            _log.debug('.fetch | result rows: $entries');
            _entries.clear();
            for (final entry in entries) {
              _log.debug('.fetch | entry[${entry.key}]: $entry');
              if (_entries.containsKey(entry.key)) {
                return Err<List<T>, Failure>(Failure(
                  message: "$runtimeType.fetch | dublicated entry key: ${entry.key}", 
                  stackTrace: StackTrace.current,
                ));
              }
              _entries[entry.key] = entry;
            } 
            return Ok<List<T>, Failure>(_entries.values.toList());
          }(),
          Err<List<T>, Failure>(:final error) => () {
            return Err<List<T>, Failure>(error);
          }(),
        };
      },
      onError: (err) {
        return Err<List<T>, Failure>(
          Failure(
              message: "$runtimeType.fetch | Error: $err", 
              stackTrace: StackTrace.current,
            ),
        );
      },
    );
  }
  ///
  /// Inserts new entry into the table schema
  @override
  Future<Result<void, Failure>> insert({T? entry}) {
    return _write.insert(entry).then((result) {
      return switch (result) {
        Ok(:final value) => () {
          final entry_ = value;
          _entries[entry_.key] = entry_;
          return const Ok<void, Failure>(null);
        }(),
        Err(:final error) => Err(error),
      };
    });
  }
  ///
  /// Updates entry of the table schema
  @override
  Future<Result<void, Failure>> update(T entry) {
    return _write.update(entry).then((result) {
      if (result is Ok) {
        entry.saved();
        _entries[entry.key] = entry;
      }
      return result;
    });
  }
  ///
  /// Deletes entry of the table schema
  @override
  Future<Result<void, Failure>> delete(T entry) {
    final write = _write;
    return write.delete(entry).then((result) {
      if (result is Ok) {
        _entries.remove(entry.key);
      }
      return result;
    });
  }
  //
  //
  @override
  Future<Result<void, Failure>> fetchRelations() {
    return Future.value(
      Err(Failure(
        message: '$runtimeType.fetchRelations | method does not exists', 
        stackTrace: StackTrace.current,
      )),
    );
  }
  //
  //
  @override
  Map<String, List<SchemaEntryAbstract>> get relations {
    return {};
  }
  //
  //
  @override
  Result<TableSchema<SchemaEntry, dynamic>, Failure> relation(String id) {
    return Err(Failure(
        message: '$runtimeType.relation | method does not exists', 
        stackTrace: StackTrace.current,
    ));
  }
  //
  //
  @override
  Future<void> close() {
    return Future.wait([
      _read.close(),
      _write.close(),
    ]);
  }
}
