
import 'package:ext_rw/src/table_schema/relation.dart';
import 'package:ext_rw/src/table_schema/schema_entry_abstract.dart';
import 'package:flutter/widgets.dart';

///
/// Replresentation settings for table column
class Field<T extends SchemaEntryAbstract> {
  final String _key;
  final String _title;
  final bool _hidden;
  final bool _edit;
  final Relation _relation;
  final Widget Function(BuildContext, T)? _builder;
  ///
  /// **Represents table column settings**
  /// - [title] - display name of the column, if null, the [key] will be displayed
  /// - [key] 
  ///   - database column name if not relation
  ///   - relation key if this is relation column
  /// - [relation] - represents column, related from another table, where from data will be gotten
  /// - [builder] - callback returns table column cell widget
  const Field({
    required String key,
    String? title,
    bool hidden = false,
    bool editable = false,
    Relation? relation,
    Widget Function(BuildContext, T)? builder,
  }) :
    _key = key,
    _title = title ?? key,
    _hidden = hidden,
    _edit = editable,
    _relation = relation ?? const Relation.empty(),
    _builder = builder;
  ///
  /// Returns [key] of [Field]
  ///   - database column name if not relation
  ///   - relation key if this is relation column
  String get key => _key;
  ///
  /// Display name of [Field] if not specified, [key] will be displayed
  String get title => _title;
  ///
  /// Column will not be displayed if `true`
  bool get isHidden => _hidden;
  ///
  /// Can be edited if `true`
  bool get isEditable => _edit;
  ///
  /// Returns [Relations] if specified, or Relation.empty will be returned
  Relation get relation => _relation;
  ///
  /// Returns cell widget build from specified [builder],  
  /// Or by default retirns Text(value)
  Widget Function(BuildContext context, T entry)? get builder => _builder;
  //
  //
  @override
  String toString() {
    return '$runtimeType{ key: $_key, title: $_title, hidden: $_hidden, editable: $_edit, relation: $_relation }';
  }
}