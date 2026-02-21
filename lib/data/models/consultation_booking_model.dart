import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { requested, confirmed, completed, cancelled, noShow }

enum ConsultationType { online, inPerson }

class ConsultationBookingModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName; // Denormalized for quick display
  final String patientName; // Denormalized for quick display
  final int? patientAge;
  final String? patientGender;
  final bool isForSelf;
  final String? familyMemberId;
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
    this.patientAge,
    this.patientGender,
    this.isForSelf = true,
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
    this.familyMemberId,
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
      patientAge: data['patientAge'],
      patientGender: data['patientGender'],
      isForSelf: data['isForSelf'] ?? true,
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
      familyMemberId: data['familyMemberId'],
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
      'patientAge': patientAge,
      'patientGender': patientGender,
      'isForSelf': isForSelf,
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
      'familyMemberId': familyMemberId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ConsultationBookingModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? doctorName,
    String? patientName,
    int? patientAge,
    String? patientGender,
    bool? isForSelf,
    String? familyMemberId,
    DateTime? dateTime,
    String? timeSlot,
    ConsultationType? type,
    BookingStatus? status,
    List<String>? attachedResultIds,
    String? patientNotes,
    String? doctorNotes,
    String? diagnosis,
    String? zoomLink,
    String? clinicAddress,
    double? latitude,
    double? longitude,
    String? exactAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConsultationBookingModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      patientName: patientName ?? this.patientName,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      isForSelf: isForSelf ?? this.isForSelf,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      dateTime: dateTime ?? this.dateTime,
      timeSlot: timeSlot ?? this.timeSlot,
      type: type ?? this.type,
      status: status ?? this.status,
      attachedResultIds: attachedResultIds ?? this.attachedResultIds,
      patientNotes: patientNotes ?? this.patientNotes,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      diagnosis: diagnosis ?? this.diagnosis,
      zoomLink: zoomLink ?? this.zoomLink,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      exactAddress: exactAddress ?? this.exactAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
