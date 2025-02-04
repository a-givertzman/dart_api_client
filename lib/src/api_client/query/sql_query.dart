import 'dart:convert';

import 'package:ext_rw/src/api_client/query/api_query_type.dart';
import 'package:uuid/uuid.dart';
///
/// Query for 'python' API service
/// - Contains database name, SQL and query additional parameters
class SqlQuery implements ApiQueryType {
  late String _id = '';
  final String _database;
  final String _sql;
  ///
  /// Prapares sql for some database
  SqlQuery({
    required String database,
    required String sql,
  }) :
    _database = database,
    _sql = sql;
  //
  //
  @override
  bool valid() {
    return true;
    /// some simplest sql syntax validation to be implemented
  }
  //
  //
  @override
  String buildJson({String authToken = '', bool debug = false, keep = false}) {
    _id = const Uuid().v1();
    final jsonString = json.encode({
      'authToken': authToken,
      'id': _id,
      'keepAlive': keep,
      'debug': debug,
      'sql': {
        'database': _database,
        'sql': _sql,
      },
    });
    return jsonString;
  }
  //
  //
  @override
  String get id => _id;
  ///
  /// Returns database name
  String get database => _database;
  //
  //
  @override
  String toString() {
    return 'SqlQuery { \n\t id: $_id, \n\t database: $database, \n\t sql: $_sql}';
  }
}