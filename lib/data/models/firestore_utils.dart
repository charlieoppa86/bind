import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? toDateTime(Object? value) => switch (value) {
  Timestamp t => t.toDate(),
  DateTime d => d,
  _ => null,
};

Timestamp? toTimestamp(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
