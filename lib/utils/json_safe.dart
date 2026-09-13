/// Makes maps/lists safe for [jsonEncode] by stripping non-finite doubles.
///
/// JSON has no Infinity/NaN; encoding those throws
/// "Converting object to an encodable object failed: Infinity".
abstract final class JsonSafe {
  /// Returns [value] with any `double` that is infinite or NaN replaced by
  /// `null`. Recurses into maps and lists.
  static Object? encodeValue(Object? value) {
    if (value is double) {
      if (value.isInfinite || value.isNaN) return null;
      return value;
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): encodeValue(entry.value),
      };
    }
    if (value is Iterable && value is! String) {
      return [for (final item in value) encodeValue(item)];
    }
    return value;
  }

  /// Profile / session maps ready for [jsonEncode].
  static Map<String, dynamic> encodeMap(Map<String, dynamic> data) {
    final encoded = encodeValue(data);
    if (encoded is Map<String, dynamic>) return encoded;
    if (encoded is Map) {
      return Map<String, dynamic>.from(encoded);
    }
    return Map<String, dynamic>.from(data);
  }

  /// Finite double for model fields — never Infinity/NaN.
  static double finiteOrZero(num? value) {
    if (value == null) return 0.0;
    final d = value.toDouble();
    if (d.isInfinite || d.isNaN) return 0.0;
    return d;
  }

  /// Finite nullable double for optional model fields.
  static double? finiteOrNull(num? value) {
    if (value == null) return null;
    final d = value.toDouble();
    if (d.isInfinite || d.isNaN) return null;
    return d;
  }
}
