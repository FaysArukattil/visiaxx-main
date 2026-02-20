import 'package:cloud_firestore/cloud_firestore.dart';

enum SlotStatus { available, booked, blocked }

class TimeSlotModel {
  final String id;
  final String doctorId;
  final DateTime date;
  final String startTime; // e.g. "10:00"
  final String endTime; // e.g. "10:20"
  final SlotStatus status;
  final String? bookingId;

  TimeSlotModel({
    required this.id,
    required this.doctorId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = SlotStatus.available,
    this.bookingId,
  });

  factory TimeSlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeSlotModel(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      status: SlotStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => SlotStatus.available,
      ),
      bookingId: data['bookingId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'doctorId': doctorId,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'status': status.toString(),
      'bookingId': bookingId,
    };
  }
}
