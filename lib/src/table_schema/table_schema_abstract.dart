import 'package:ext_rw/ext_rw.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_result.dart';

///
/// A collection of the SchameEntry, 
/// abstruction on the table rows
abstract interface class TableSchemaAbstract<T extends SchemaEntryAbstract, P> implements Schema<T, P> {
  ///
  /// Returns a list of table fields
  List<Field<T>> get fields;
  ///
  /// Returns a list of table field keys
  List<String> get keys;
  ///
  /// Returns table row's data
  Map<String, T> get entries;
  ///
  /// Fetchs data with new sql built from [values]
  @override
  Future<Result<List<T>, Failure>> fetch(P? params);
  ///
  /// Returns relations as Map<String, List<SchemaEntryAbstract>>
  Map<String, List<SchemaEntryAbstract>> get relations;
  ///
  /// Returns relation Result<schema> if exists else Result<Failure>
  Result<TableSchemaAbstract, Failure> relation(String id);
  ///
  /// Inserts new entry into the table schema
  @override
  Future<Result<void, Failure>> insert({T? entry});
  ///
  /// Updates entry of the table schema
  @override
  Future<Result<void, Failure>> update(T entry);
  ///
  /// Deletes entry of the table schema
  @override
  Future<Result<void, Failure>> delete(T entry);
  ///
  /// Fetchs data of the relation schemas only (with existing sql)
  Future<Result<void, Failure>> fetchRelations();
  ///
  /// Closes connection
  @override
  Future<void> close();
}
