// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Scan {

 String get id; String get name; DateTime get createdAt; ScanStatus get status; String? get thumbnailPath; String? get modelPath; int get bytes; bool get isFavorite; List<String> get tags;
/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScanCopyWith<Scan> get copyWith => _$ScanCopyWithImpl<Scan>(this as Scan, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Scan;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Scan&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.thumbnailPath, _this.thumbnailPath) || other.thumbnailPath == _this.thumbnailPath)&&(identical(other.modelPath, _this.modelPath) || other.modelPath == _this.modelPath)&&(identical(other.bytes, _this.bytes) || other.bytes == _this.bytes)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite)&&const DeepCollectionEquality().equals(other.tags, _this.tags));
}


@override
int get hashCode {
  final _this = this as Scan;
  return Object.hash(runtimeType,_this.id,_this.name,_this.createdAt,_this.status,_this.thumbnailPath,_this.modelPath,_this.bytes,_this.isFavorite,const DeepCollectionEquality().hash(_this.tags));
}

@override
String toString() {
  final _this = this as Scan;
  return 'Scan(id: ${_this.id}, name: ${_this.name}, createdAt: ${_this.createdAt}, status: ${_this.status}, thumbnailPath: ${_this.thumbnailPath}, modelPath: ${_this.modelPath}, bytes: ${_this.bytes}, isFavorite: ${_this.isFavorite}, tags: ${_this.tags})';
}


}

/// @nodoc
abstract mixin class $ScanCopyWith<$Res>  {
  factory $ScanCopyWith(Scan value, $Res Function(Scan) _then) = _$ScanCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime createdAt, ScanStatus status, String? thumbnailPath, String? modelPath, int bytes, bool isFavorite, List<String> tags
});




}
/// @nodoc
class _$ScanCopyWithImpl<$Res>
    implements $ScanCopyWith<$Res> {
  _$ScanCopyWithImpl(this._self, this._then);

  final Scan _self;
  final $Res Function(Scan) _then;

/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? status = null,Object? thumbnailPath = freezed,Object? modelPath = freezed,Object? bytes = null,Object? isFavorite = null,Object? tags = null,}) {
  return _then(Scan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ScanStatus,thumbnailPath: freezed == thumbnailPath ? _self.thumbnailPath : thumbnailPath // ignore: cast_nullable_to_non_nullable
as String?,modelPath: freezed == modelPath ? _self.modelPath : modelPath // ignore: cast_nullable_to_non_nullable
as String?,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Scan].
extension ScanPatterns on Scan {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Scan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Scan value)  $default,){
final _that = this;
switch (_that) {
case _Scan():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Scan value)?  $default,){
final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  ScanStatus status,  String? thumbnailPath,  String? modelPath,  int bytes,  bool isFavorite,  List<String> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.status,_that.thumbnailPath,_that.modelPath,_that.bytes,_that.isFavorite,_that.tags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  ScanStatus status,  String? thumbnailPath,  String? modelPath,  int bytes,  bool isFavorite,  List<String> tags)  $default,) {final _that = this;
switch (_that) {
case _Scan():
return $default(_that.id,_that.name,_that.createdAt,_that.status,_that.thumbnailPath,_that.modelPath,_that.bytes,_that.isFavorite,_that.tags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime createdAt,  ScanStatus status,  String? thumbnailPath,  String? modelPath,  int bytes,  bool isFavorite,  List<String> tags)?  $default,) {final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.status,_that.thumbnailPath,_that.modelPath,_that.bytes,_that.isFavorite,_that.tags);case _:
  return null;

}
}

}

/// @nodoc


class _Scan implements Scan {
  const _Scan({required this.id, required this.name, required this.createdAt, this.status = ScanStatus.draft, this.thumbnailPath, this.modelPath, this.bytes = 0, this.isFavorite = false,  List<String> tags = const <String>[]}): _tags = tags;
  

@override final  String id;
@override final  String name;
@override final  DateTime createdAt;
@override@JsonKey() final  ScanStatus status;
@override final  String? thumbnailPath;
@override final  String? modelPath;
@override@JsonKey() final  int bytes;
@override@JsonKey() final  bool isFavorite;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}


/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScanCopyWith<_Scan> get copyWith => __$ScanCopyWithImpl<_Scan>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Scan&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.thumbnailPath, thumbnailPath) || other.thumbnailPath == thumbnailPath)&&(identical(other.modelPath, modelPath) || other.modelPath == modelPath)&&(identical(other.bytes, bytes) || other.bytes == bytes)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&const DeepCollectionEquality().equals(other.tags, _tags));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,createdAt,status,thumbnailPath,modelPath,bytes,isFavorite,const DeepCollectionEquality().hash(_tags));
}

@override
String toString() {
    return 'Scan(id: $id, name: $name, createdAt: $createdAt, status: $status, thumbnailPath: $thumbnailPath, modelPath: $modelPath, bytes: $bytes, isFavorite: $isFavorite, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$ScanCopyWith<$Res> implements $ScanCopyWith<$Res> {
  factory _$ScanCopyWith(_Scan value, $Res Function(_Scan) _then) = __$ScanCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime createdAt, ScanStatus status, String? thumbnailPath, String? modelPath, int bytes, bool isFavorite, List<String> tags
});




}
/// @nodoc
class __$ScanCopyWithImpl<$Res>
    implements _$ScanCopyWith<$Res> {
  __$ScanCopyWithImpl(this._self, this._then);

  final _Scan _self;
  final $Res Function(_Scan) _then;

/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? status = null,Object? thumbnailPath = freezed,Object? modelPath = freezed,Object? bytes = null,Object? isFavorite = null,Object? tags = null,}) {
  return _then(_Scan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ScanStatus,thumbnailPath: freezed == thumbnailPath ? _self.thumbnailPath : thumbnailPath // ignore: cast_nullable_to_non_nullable
as String?,modelPath: freezed == modelPath ? _self.modelPath : modelPath // ignore: cast_nullable_to_non_nullable
as String?,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
