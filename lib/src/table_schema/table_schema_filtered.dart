import 'package:ext_rw/ext_rw.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_result.dart';

///
/// A collection of the SchameEntry, abstruction on the SQL table rows
/// - Filtered by [filter] closure callback 
class TableSchemaFiltered<T extends SchemaEntryAbstract, P> implements TableSchemaAbstract<T, P> {
  late final Log _log;
  final TableSchemaAbstract<T, P> _schema;
  final bool Function(T) _filter;
  ///
  /// A collection of the SchameEntry, 
  /// abstruction on the SQL table rows
  /// - [keys] - list of table field names
  TableSchemaFiltered({
    required TableSchemaAbstract<T, P> schema,
    required bool Function(T entry) filter,
  }) :
    _schema = schema,
    _filter = filter {
    _log = Log("$runtimeType")..level = LogLevel.info;
  }
  ///
  /// Returns a list of table field names
  @override
  List<Field<T>> get fields {
    return _schema.fields;
  }
  ///
  /// Returns a list of table field keys
  @override
  List<String> get keys {
    return _schema.entries.entries
      .where((entry) => _filter(entry.value))
      .map((entry) => entry.key)
      .toList();
  }
  //
  //
  @override
  Map<String, T> get entries => {
    for (final MapEntry(:key, :value) in _schema.entries.entries)
      if (_filter(value)) key: value,
  };
  ///
  /// Fetchs data with new sql built from [values]
  @override
  Future<Result<List<T>, Failure>> fetch(P? params) async {
    _log.warning('.fetch | ...');
    return _schema.fetch(params).then(
      (result) {
        switch (result) {
          case Ok<List<T>, Failure>(value: final entries):
            final result = entries.where((entry) => _filter(entry)).toList();
            return Ok(result);
          case Err<List<T>, Failure>(: final error):
            return Err<List<T>, Failure>(
              Failure(message: "$runtimeType.fetch | Error: $error", stackTrace: StackTrace.current),
            );
        }
      },
      onError: (err) {
        return Err<List<T>, Failure>(
          Failure(message: "$runtimeType.fetch | Error: $err", stackTrace: StackTrace.current),
        );
      },
    );
  }
  ///
  /// Inserts new entry into the table schema
  @override
  Future<Result<void, Failure>> insert({T? entry}) {
    return _schema.insert(entry: entry);
  }
  ///
  /// Updates entry of the table schema
  @override
  Future<Result<void, Failure>> update(T entry) {
    return _schema.update(entry);
  }
  ///
  /// Deletes entry of the table schema
  @override
  Future<Result<void, Failure>> delete(T entry) {
    return _schema.delete(entry);
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
  Map<String, List<SchemaEntryAbstract>> get relations => _schema.relations;
  //
  //
  @override
  Result<TableSchemaAbstract<SchemaEntryAbstract, dynamic>, Failure> relation(String id) {
    return _schema.relation(id);
  }
  //
  //
  @override
  Future<void> close() {
    return _schema.close();
  }
}
