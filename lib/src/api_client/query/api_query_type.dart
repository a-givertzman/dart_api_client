abstract class ApiQueryType {
  ///
  ///Returns true if query validetions passed
  bool valid();
  ///
  /// Returns built JSON string 
  String buildJson({String authToken = '', bool debug = false, keep = false});
  ///
  /// Returns id of query 
  String get id;
}