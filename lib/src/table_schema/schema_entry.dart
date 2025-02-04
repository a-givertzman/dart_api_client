
import 'package:ext_rw/src/table_schema/field_value.dart';
import 'package:ext_rw/src/table_schema/schema_entry_abstract.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:uuid/uuid.dart';
///
/// Abstruction on the SQL table single row
class SchemaEntry implements SchemaEntryAbstract {
  final _log = Log("$SchemaEntry");
  final _id = const Uuid().v1();  // v1 time-based id
  final Map<String, FieldValue> _map;
  bool _isEmpty;
  bool _isChanged =  false;
  bool _isSelected = false;
  ///
  ///
  SchemaEntry({
    Map<String, FieldValue>? map,
  }):
    _map = map ?? const {},
    _isEmpty = map != null && map.isNotEmpty ? false : true;
  ///
  /// Creates entry from database row
  SchemaEntry.from(Map<String, dynamic> row, {Map<String, FieldValue>? def}):
    _isEmpty = false,
    _map = {} {
    for (final MapEntry(:key, :value) in def?.entries ?? {}.entries) {
      final rowValue = row[key];
      _map[key] = rowValue != null ? FieldValue(rowValue) : value;
    }
    for (final MapEntry(:key, :value) in row.entries) {
      _map[key] = FieldValue(value);
    }
  }
  ///
  /// Creates entry with empty / default values
  SchemaEntry.empty(): 
    _map = {},
    _isEmpty = true;
  ///
  /// Returns inner unique identificator of the entry, not related to the database table
  @override
  String get key => _id;
  //
  //
  @override
  bool get isChanged => _isChanged;
  ///
  ///
  bool isValueChanged(String key) {
    final value = _map[key];
    if (value != null) {
      return value.isChanged;
    }
    throw Failure(
      message: "$runtimeType.isValueChanged | key '$key' - not found", 
      stackTrace: StackTrace.current,
    );
  }
  ///
  /// Returns selection state
  @override
  bool get isSelected => _isSelected;
  //
  //
  @override
  bool get isEmpty => _isEmpty;
  ///
  /// Returns field value by field name [key]
  @override
  FieldValue value(String key)  {
    final value = _map[key];
    if (value != null) {
      return value;
    }
    throw Failure(
      message: "$runtimeType.value | key '$key' - not found", 
      stackTrace: StackTrace.current,
    );
  }
  ///
  /// Updates field value by field name [key]
  @override
  void update(String key, dynamic value) {
    _log.debug('.update | key: $key, \t value: $value, \t valuetype: ${value.runtimeType}');
    if (!_map.containsKey(key)) {
      throw Failure(
        message: "$runtimeType.update | key '$key' - not found", 
        stackTrace: StackTrace.current,
      );
    }
    final field = _map[key];
    _log.debug('.update | key: $key, \t field: $field');
    if (field != null) {
      final changed = field.update(value);
      _isChanged = _isChanged || changed;
      if (_isChanged) {
        _isEmpty = false;
      }
    }
    _log.debug('.update | key: $key, \t field: $field, isChanged: $_isChanged');
  }
  ///
  /// Set selection state
  @override
  void select(bool selected) {
    if (_isSelected != selected) _isSelected = selected;
  }
  ///
  /// Set isChanged to false
  @override
  void saved() {
    _isChanged = false;
  }
  //
  //
  @override
  String toString() {
    return '$runtimeType{ isEmpty: $_isEmpty, isChanged: $_isChanged, isSelected: $_isSelected, map: $_map}';
  }
}
