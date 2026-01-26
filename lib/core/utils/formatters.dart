import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Fmt {
  static final DateFormat _dt = DateFormat('dd/MM/yyyy HH:mm');

  static String dateTimeFromTimestamp(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return _dt.format(ts.toDate());
    }
    return ts.toString();
  }

  static String km(dynamic v) {
    if (v == null) return '—';
    if (v is num) return v.toStringAsFixed(0);
    return v.toString();
  }

  static String totalKm(dynamic start, dynamic end) {
    if (start is num && end is num) {
      final diff = end - start;
      if (diff >= 0) return diff.toStringAsFixed(0);
    }
    return '—';
  }

  static String cleanStr(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }
}
