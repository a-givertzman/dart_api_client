import 'package:ext_rw/ext_rw.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_result.dart';

///
/// A collection of the SchameEntry, 
/// abstruction on the SQL table rows
class RelationSchema<T extends SchemaEntryAbstract, P> implements TableSchemaAbstract<T, P> {
  late final Log _log;
  final TableSchemaAbstract<T, P> _schema;
  final Map<String, TableSchemaAbstract> _relations;
  ///
  /// A collection of the SchameEntry, 
  /// abstruction on the SQL table rows
  /// - [keys] - list of table field names
  RelationSchema({
    required TableSchemaAbstract<T, P> schema,
    Map<String, TableSchemaAbstract> relations = const {},
  }) :
    _schema = schema,
    _relations = relations {
      _log = Log("$runtimeType");
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
    return _schema.keys;
  }
  //
  //
  @override
  Map<String, T> get entries => _schema.entries;
  ///
  /// Fetchs data with new sql built from [values]
  @override
  Future<Result<List<T>, Failure>> fetch(params) async {
    await fetchRelations();
    return _schema.fetch(params);
  }
  @override
  Map<String, List<SchemaEntryAbstract>> get relations {
    return _relations.map((key, scheme) {
      final entries = scheme.entries;
      return MapEntry(key, entries.values.toList());
    });
  }
  //
  //
  @override
  Result<TableSchemaAbstract, Failure> relation(String id) {
    final rel = _relations[id];
    if (rel != null) {
      return Ok(rel);
    } else {
      return Err(Failure(
        message: "$runtimeType.relation | id: $id - not found", 
        stackTrace: StackTrace.current,
      ));
    }
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
  ///
  /// Fetchs data of the relation schemas only (with existing sql)
  @override
  Future<Result<void, Failure>> fetchRelations() async {
    Result<void, Failure> result = const Ok(null);
    for (final field in _schema.fields) {
      if (field.relation.isNotEmpty) {
        switch (relation(field.relation.id)) {
          case Ok(:final value):
            await value.fetch(null);
          case Err(:final error):
            final message = "$runtimeType.fetchRelations | relation '${field.relation}' - not found\n\terror: $error";
            _log.warning(message);
            result = Err(Failure(
              message: message, 
              stackTrace: StackTrace.current,
            ));
        }
      }
    }
    return result;
  }
  //
  //
  @override
  Future<void> close() {
    return Future.wait([
      _schema.close(),
      ..._relations.values.map((schema) {
        return schema.close();
      }),
    ]);
  }
}
