/// Centralized Firestore REST API JSON Value Serializer & Deserializer.
class FirestoreRestSerializer {
  /// Converts a standard Dart map into a Firestore REST fields map.
  static Map<String, dynamic> toFirestoreFields(Map<String, dynamic> data) {
    final Map<String, dynamic> fields = {};
    data.forEach((key, value) {
      fields[key] = encodeValue(value);
    });
    return fields;
  }

  /// Encodes a single Dart object into a Firestore REST typed value object.
  static Map<String, dynamic> encodeValue(dynamic value) {
    if (value == null) {
      return {'nullValue': null};
    } else if (value is bool) {
      return {'booleanValue': value};
    } else if (value is int) {
      return {'integerValue': value.toString()};
    } else if (value is double) {
      return {'doubleValue': value};
    } else if (value is String) {
      return {'stringValue': value};
    } else if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    } else if (value is List) {
      return {
        'arrayValue': {
          'values': value.map((item) => encodeValue(item)).toList(),
        }
      };
    } else if (value is Map) {
      final Map<String, dynamic> mapFields = {};
      value.forEach((k, v) {
        mapFields[k.toString()] = encodeValue(v);
      });
      return {
        'mapValue': {
          'fields': mapFields,
        }
      };
    }
    return {'stringValue': value.toString()};
  }

  /// Converts a Firestore REST fields map back into a standard Dart map.
  static Map<String, dynamic> fromFirestoreFields(Map<String, dynamic> fields) {
    final Map<String, dynamic> map = {};
    fields.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        map[key] = decodeValue(value);
      }
    });
    return map;
  }

  /// Decodes a Firestore REST typed value object into a standard Dart object.
  static dynamic decodeValue(Map<String, dynamic> valueMap) {
    if (valueMap.containsKey('stringValue')) {
      return valueMap['stringValue'];
    } else if (valueMap.containsKey('integerValue')) {
      return int.tryParse(valueMap['integerValue'].toString()) ?? 0;
    } else if (valueMap.containsKey('doubleValue')) {
      return (valueMap['doubleValue'] is num)
          ? (valueMap['doubleValue'] as num).toDouble()
          : 0.0;
    } else if (valueMap.containsKey('booleanValue')) {
      return valueMap['booleanValue'] == true;
    } else if (valueMap.containsKey('timestampValue')) {
      return DateTime.tryParse(valueMap['timestampValue'].toString()) ?? DateTime.now();
    } else if (valueMap.containsKey('nullValue')) {
      return null;
    } else if (valueMap.containsKey('arrayValue')) {
      final rawList = valueMap['arrayValue']?['values'] as List?;
      if (rawList == null) return [];
      return rawList.map((item) => decodeValue(item as Map<String, dynamic>)).toList();
    } else if (valueMap.containsKey('mapValue')) {
      final mapFields = valueMap['mapValue']?['fields'] as Map<String, dynamic>?;
      if (mapFields == null) return {};
      return fromFirestoreFields(mapFields);
    }
    return null;
  }
}
