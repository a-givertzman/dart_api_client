import 'dart:convert';

import 'package:ext_rw/src/api_client/query/api_query_type.dart';
import 'package:uuid/uuid.dart';
///
/// Query for `python` API service
class PythonQuery implements ApiQueryType {
  late String _id;
  final String _script;
  final Map<String, dynamic> _params;
  ///
  /// Prapares query for some python script
  PythonQuery({
    required String script,
    required Map<String, dynamic> params,
    bool keepAlive = false,
  }) :
    _script = script,
    _params = params;
  //
  //
  @override
  bool valid() {
    return true;
    /// TODO some simplest validation to be implemented
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
      'python': {
        'script': _script,
        'params': _params,
      },
    });
    return jsonString;
  }
  //
  //
  @override
  String get id => _id;
  ///
  /// Returns contained python script
  String get script => _script;
}