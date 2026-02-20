import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/consultation_booking_model.dart';
import '../../data/models/time_slot_model.dart';

class ConsultationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String doctorsCollection = 'Doctors';
  static const String bookingsCollection = 'consultation_bookings';
  static const String slotsCollection = 'doctor_time_slots';

  // --- Doctor Operations ---

  /// Fetch all doctors with their basic profile info
  Future<List<DoctorModel>> getAllDoctors() async {
    try {
      final querySnapshot = await _firestore
          .collection(doctorsCollection)
          .get();
      return querySnapshot.docs
          .map((doc) => DoctorModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[ConsultationService] Error fetching doctors: $e');
      return [];
    }
  }

  /// Get specific doctor details
  Future<DoctorModel?> getDoctorById(String doctorId) async {
    try {
      final doc = await _firestore
          .collection(doctorsCollection)
          .doc(doctorId)
          .get();
      if (doc.exists) {
        return DoctorModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('[ConsultationService] Error fetching doctor $doctorId: $e');
      return null;
    }
  }

  // --- Slot Operations ---

  /// Fetch available time slots for a doctor on a specific date
  Future<List<TimeSlotModel>> getAvailableSlots(
    String doctorId,
    DateTime date,
  ) async {
    try {
      // Normalize date to YYYY-MM-DD for consistency
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final querySnapshot = await _firestore
          .collection(slotsCollection)
          .doc(doctorId)
          .collection(dateKey)
          .where('status', isEqualTo: 'SlotStatus.available')
          .get();

      return querySnapshot.docs
          .map((doc) => TimeSlotModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[ConsultationService] Error fetching slots: $e');
      return [];
    }
  }

  // --- Booking Operations ---

  /// Request a new consultation booking
  Future<String?> requestBooking(
    ConsultationBookingModel booking,
    String slotId,
  ) async {
    try {
      final batch = _firestore.batch();

      // 1. Create booking document
      final bookingRef = _firestore.collection(bookingsCollection).doc();
      final finalBooking = ConsultationBookingModel(
        id: bookingRef.id,
        patientId: booking.patientId,
        doctorId: booking.doctorId,
        doctorName: booking.doctorName,
        patientName: booking.patientName,
        dateTime: booking.dateTime,
        timeSlot: booking.timeSlot,
        type: booking.type,
        status: BookingStatus.requested,
        attachedResultIds: booking.attachedResultIds,
        patientNotes: booking.patientNotes,
        clinicAddress: booking.clinicAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      batch.set(bookingRef, finalBooking.toFirestore());

      // 2. Update slot status to booked (optimistic locking/concurrency handling recommended in production)
      final dateKey =
          '${booking.dateTime.year}-${booking.dateTime.month.toString().padLeft(2, '0')}-${booking.dateTime.day.toString().padLeft(2, '0')}';
      final slotRef = _firestore
          .collection(slotsCollection)
          .doc(booking.doctorId)
          .collection(dateKey)
          .doc(slotId);

      batch.update(slotRef, {
        'status': SlotStatus.booked.toString(),
        'bookingId': bookingRef.id,
      });

      await batch.commit();
      return bookingRef.id;
    } catch (e) {
      print('[ConsultationService] Error creating booking: $e');
      return null;
    }
  }

  /// Get all bookings for a patient
  Future<List<ConsultationBookingModel>> getPatientBookings(
    String patientId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(bookingsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('dateTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ConsultationBookingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[ConsultationService] Error fetching patient bookings: $e');
      return [];
    }
  }

  /// Get all bookings for a doctor
  Future<List<ConsultationBookingModel>> getDoctorBookings(
    String doctorId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(bookingsCollection)
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('dateTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ConsultationBookingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[ConsultationService] Error fetching doctor bookings: $e');
      return [];
    }
  }

  /// Update booking status (confirm/reject/cancel)
  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus, {
    String? doctorNotes,
    String? zoomLink,
  }) async {
    try {
      final updates = {
        'status': newStatus.toString(),
        'updatedAt': Timestamp.now(),
      };

      if (doctorNotes != null) updates['doctorNotes'] = doctorNotes;
      if (zoomLink != null) updates['zoomLink'] = zoomLink;

      await _firestore
          .collection(bookingsCollection)
          .doc(bookingId)
          .update(updates);
      return true;
    } catch (e) {
      print('[ConsultationService] Error updating booking status: $e');
      return false;
    }
  }

  /// Create a new time slot
  Future<bool> createSlot(String doctorId, TimeSlotModel slot) async {
    try {
      final dateKey =
          '${slot.date.year}-${slot.date.month.toString().padLeft(2, '0')}-${slot.date.day.toString().padLeft(2, '0')}';

      final docRef = _firestore
          .collection(slotsCollection)
          .doc(doctorId)
          .collection(dateKey)
          .doc();

      final newSlot = TimeSlotModel(
        id: docRef.id,
        doctorId: doctorId,
        date: slot.date,
        startTime: slot.startTime,
        endTime: slot.endTime,
        status: slot.status,
      );

      await docRef.set(newSlot.toFirestore());
      return true;
    } catch (e) {
      print('[ConsultationService] Error creating slot: $e');
      return false;
    }
  }

  /// Delete a time slot
  Future<bool> deleteSlot(String doctorId, DateTime date, String slotId) async {
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection(slotsCollection)
          .doc(doctorId)
          .collection(dateKey)
          .doc(slotId)
          .delete();
      return true;
    } catch (e) {
      print('[ConsultationService] Error deleting slot: $e');
      return false;
    }
  }

  /// Fetch all slots for a doctor on a specific date (including booked/unavailable)
  Future<List<TimeSlotModel>> getAllSlotsForDate(
    String doctorId,
    DateTime date,
  ) async {
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final querySnapshot = await _firestore
          .collection(slotsCollection)
          .doc(doctorId)
          .collection(dateKey)
          .get();

      return querySnapshot.docs
          .map((doc) => TimeSlotModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[ConsultationService] Error fetching all slots: $e');
      return [];
    }
  }

  /// Get all unique patients who have booked with this doctor
  Future<List<UserModel>> getDoctorPatients(String doctorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(bookingsCollection)
          .where('doctorId', isEqualTo: doctorId)
          .get();

      final patientIds = querySnapshot.docs
          .map((doc) => doc.data()['patientId'] as String)
          .toSet()
          .toList();

      if (patientIds.isEmpty) return [];

      // Fetch user data for each patient
      final List<UserModel> patients = [];
      // We can't use batch for single doc lookups easily across collections,
      // so we use Parallel futures for efficiency
      final futures = patientIds.map(
        (id) => _firestore.collection('all_users_lookup').doc(id).get(),
      );

      final lookupSnaps = await Future.wait(futures);

      final List<Future<DocumentSnapshot>> patientFutures = [];
      for (final snap in lookupSnaps) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final collection = data['collection'] as String;
          final identityString = data['identityString'] as String;
          patientFutures.add(
            _firestore.collection(collection).doc(identityString).get(),
          );
        }
      }

      final patientSnaps = await Future.wait(patientFutures);
      for (final snap in patientSnaps) {
        if (snap.exists && snap.data() != null) {
          patients.add(
            UserModel.fromMap(snap.data() as Map<String, dynamic>, snap.id),
          );
        }
      }

      return patients;
    } catch (e) {
      print('[ConsultationService] Error fetching doctor patients: $e');
      return [];
    }
  }

  /// Complete a consultation with diagnosis and notes
  Future<bool> completeConsultation(
    String bookingId,
    String diagnosis,
    String doctorNotes,
  ) async {
    try {
      await _firestore.collection(bookingsCollection).doc(bookingId).update({
        'status': BookingStatus.completed.toString(),
        'diagnosis': diagnosis,
        'doctorNotes': doctorNotes,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('[ConsultationService] Error completing consultation: $e');
      return false;
    }
  }
}
