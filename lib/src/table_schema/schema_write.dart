import 'package:ext_rw/src/table_schema/schema_entry.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_result_new.dart';

///
/// Abstraction on write data access
abstract interface class SchemaWrite<T extends SchemaEntry> {
  ///
  /// Empty instance implements SchemaRead
  const factory SchemaWrite.empty() = _SchemaWriteEmpty;
  ///
  /// Inserts new entry into the source
  Future<Result<void, Failure>> update(T entry);
  ///
  /// Updates entry at the source
  Future<Result<T, Failure>> insert(T? entry);
  ///
  /// Deletes entry from the source
  Future<Result<void, Failure>> delete(T entry);
}
///
/// Empty instance implements SchemaRead
class _SchemaWriteEmpty<T extends SchemaEntry> implements SchemaWrite<T> {
  ///
  ///
  const _SchemaWriteEmpty();
  //
  //
  @override
  Future<Result<void, Failure>> delete(T entry) {
    return Future.value(Err(Failure(
      message: "$runtimeType.delete | write - not initialized", 
      stackTrace: StackTrace.current,
    )));
  }
  //
  //
  @override
  Future<Result<T, Failure>> insert(T? entry) {
    return Future.value(Err(Failure(
      message: "$runtimeType.insert | write - not initialized", 
      stackTrace: StackTrace.current,
    )));
  }
  //
  //
  @override
  Future<Result<void, Failure>> update(T entry) {
    return Future.value(Err(Failure(
      message: "$runtimeType.update | write - not initialized", 
      stackTrace: StackTrace.current,
    )));
  }
}