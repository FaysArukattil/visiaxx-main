import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { requested, confirmed, completed, cancelled, noShow }

enum ConsultationType { online, inPerson }

class ConsultationBookingModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName; // Denormalized for quick display
  final String patientName; // Denormalized for quick display
  final DateTime dateTime;
  final String timeSlot; // e.g., "10:00 AM"
  final ConsultationType type;
  final BookingStatus status;
  final List<String> attachedResultIds;
  final String? patientNotes;
  final String? doctorNotes;
  final String? diagnosis;
  final String? zoomLink; // For online consultations
  final String? clinicAddress; // For in-person consultations
  final double? latitude;
  final double? longitude;
  final String? exactAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConsultationBookingModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.patientName,
    required this.dateTime,
    required this.timeSlot,
    required this.type,
    this.status = BookingStatus.requested,
    this.attachedResultIds = const [],
    this.patientNotes,
    this.doctorNotes,
    this.diagnosis,
    this.zoomLink,
    this.clinicAddress,
    this.latitude,
    this.longitude,
    this.exactAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConsultationBookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConsultationBookingModel(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      patientName: data['patientName'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      timeSlot: data['timeSlot'] ?? '',
      type: ConsultationType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => ConsultationType.online,
      ),
      status: BookingStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => BookingStatus.requested,
      ),
      attachedResultIds: List<String>.from(data['attachedResultIds'] ?? []),
      patientNotes: data['patientNotes'],
      doctorNotes: data['doctorNotes'],
      diagnosis: data['diagnosis'],
      zoomLink: data['zoomLink'],
      clinicAddress: data['clinicAddress'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      exactAddress: data['exactAddress'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientName': patientName,
      'dateTime': Timestamp.fromDate(dateTime),
      'timeSlot': timeSlot,
      'type': type.toString(),
      'status': status.toString(),
      'attachedResultIds': attachedResultIds,
      'patientNotes': patientNotes,
      'doctorNotes': doctorNotes,
      'diagnosis': diagnosis,
      'zoomLink': zoomLink,
      'clinicAddress': clinicAddress,
      'latitude': latitude,
      'longitude': longitude,
      'exactAddress': exactAddress,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
