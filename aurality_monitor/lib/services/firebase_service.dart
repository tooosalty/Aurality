import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';

/// Handles all Firestore operations for the alerts dashboard.
/// Listens to `alerts` collection, filtering to status == 'new'.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._();
  factory FirebaseService() => _instance;
  FirebaseService._();

  final CollectionReference _alertsRef = FirebaseFirestore.instance.collection(
    'alerts',
  );

  /// Live stream of alerts where status == 'new', ordered newest first.
  Stream<List<AlertModel>> alertsStream() {
    return _alertsRef
        .where('status', isEqualTo: 'new')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return AlertModel.fromFirestore(doc);
                } catch (_) {
                  return null;
                }
              })
              .whereType<AlertModel>()
              .toList();
        });
  }

  /// Mark an alert as 'dismissed' in Firestore (soft delete — keeps audit trail).
  Future<void> dismissAlert(String alertId) async {
    await _alertsRef.doc(alertId).update({'status': 'dismissed'});
  }

  /// Mark an alert as 'acknowledged' (HITL confirm).
  Future<void> acknowledgeAlert(String alertId) async {
    await _alertsRef.doc(alertId).update({
      'status': 'acknowledged',
      'ackAt': FieldValue.serverTimestamp(),
    });
  }
}
