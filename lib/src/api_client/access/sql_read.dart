import 'package:ext_rw/ext_rw.dart';
import 'package:hmi_core/hmi_core_failure.dart';
import 'package:hmi_core/hmi_core_log.dart';
import 'package:hmi_core/hmi_core_result.dart';
///
/// Performs a request(s) to the API server
/// - `SqlRead.keep` can be fetched multiple times, call `close()` at the end
class SqlRead<T extends SchemaEntryAbstract, P> implements SchemaRead<T, P> {
  late final Log _log;
  final String _database;
  final SqlBuilder<P?> _sqlBuilder;
  final T Function(Map<String, dynamic> row) _entryBuilder;
  Sql _sql = Sql(sql: '');
  final ApiRequest _request;
  ///
  /// Performs a request to the API server
  /// - Can be fetched only once, closes automatically
  /// - `authToken` - authentication parameter, dipends on authentication kind
  /// - `address` - IP and port of the API server
  /// - `database` - database name
  /// - `timeout` - time to wait read, write & connection until timeout error, default - 3 sec
  SqlRead({
    required ApiAddress address,
    required String authToken,
    required String database,
    Duration timeout = const Duration(milliseconds: 3000),
    bool debug = false,
    required SqlBuilder<P?> sqlBuilder,
    required T Function(Map<String, dynamic> row) entryBuilder,
  }) :
    _database = database,
    _sqlBuilder = sqlBuilder,
    _entryBuilder = entryBuilder,
    _request = ApiRequest(
      address: address, 
      authToken: authToken, 
      timeout: timeout,
      debug: debug,
      query: SqlQuery(
        database: database,
        sql: '',
      ),
    ) {
    _log = Log("$runtimeType")..level = LogLevel.info;
  }
  ///
  /// Performs a requests to the API server
  /// - Can be fetched multiple times, call `close()` at the end
  /// - `authToken` - authentication parameter, dipends on authentication kind
  /// - `address` - IP and port of the API server
  /// - `database` - database name
  /// - `timeout` - time to wait read, write & connection until timeout error, default - 3 sec
  SqlRead.keep({
    required ApiAddress address,
    required String authToken,
    required String database,
    Duration timeout = const Duration(milliseconds: 3000),
    bool debug = false,
    required SqlBuilder<P?> sqlBuilder,
    required T Function(Map<String, dynamic> row) entryBuilder,
  }) :
    _database = database,
    _sqlBuilder = sqlBuilder,
    _entryBuilder = entryBuilder,
    _request = ApiRequest.keep(
      address: address, 
      authToken: authToken, 
      timeout: timeout,
      debug: debug,
      query: SqlQuery(
        database: database,
        sql: '',
      ),
    ) {
    _log = Log("$runtimeType")..level = LogLevel.info;
  }
  //
  //
  @override
  Future<Result<List<T>, Failure>> fetch({P? params}) {
    _sql = _sqlBuilder(_sql, params);
    return _fetch(_sql);
  }
  ///
  /// Fetchs data with [sql]
  Future<Result<List<T>, Failure>> _fetch(Sql sql) {
    final query = SqlQuery(
      database: _database,
      sql: sql.build(),
    );
    _log.debug("._fetch | query: $query");
    return _request.fetchWith(query)
      .then((result) {
        return switch (result) {
          Ok(value :final reply) => () {
            _log.debug("._fetch | reply: $reply");
            if (reply.hasError) {
              return Err<List<T>, Failure>(Failure(message: reply.error.message, stackTrace: StackTrace.current));
            } else {
              final List<T> entries = [];
              final rows = reply.data;
              final rowsLength = rows.length;
              _log.debug("._fetch | reply rows ($rowsLength): $rows");
              for (final row in rows) {
                _log.debug("._fetch | row: $row");
                final entry = _entryBuilder(row);
                _log.debug("._fetch | entry: $entry");
                entries.add(entry);
              }
              _log.debug("._fetch | entries: $entries");
              return Ok<List<T>, Failure>(entries);
            }
          }(), 
          Err(:final error) => () {
            _log.debug("._fetch | error: $error");
            return Err<List<T>, Failure>(error);
          }(),
        };
      },
      onError: (err) {
        return Err<List<T>, Failure>(Failure(message: '$runtimeType._fetch | Error: $err', stackTrace: StackTrace.current));
      },
    );
  }
  //
  //
  @override
  Future<void> close() {
    return _request.close();
  }
}