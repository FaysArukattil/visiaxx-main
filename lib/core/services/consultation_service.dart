import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
      // 1. Try direct fetch (works if doctorId is identityString)
      var doc = await _firestore
          .collection(doctorsCollection)
          .doc(doctorId)
          .get();

      if (doc.exists) {
        return DoctorModel.fromFirestore(doc);
      }

      // 2. Not found? Try UID-based lookup from all_users_lookup
      final lookupDoc = await _firestore
          .collection('all_users_lookup')
          .doc(doctorId)
          .get();

      if (lookupDoc.exists && lookupDoc.data() != null) {
        final identity = lookupDoc.data()!['identityString'] as String;
        doc = await _firestore
            .collection(doctorsCollection)
            .doc(identity)
            .get();
        if (doc.exists) {
          return DoctorModel.fromFirestore(doc);
        }
      }

      return null;
    } catch (e) {
      print('[ConsultationService] Error fetching doctor $doctorId: $e');
      return null;
    }
  }

  /// Update doctor professional profile
  Future<bool> updateDoctorProfile(DoctorModel doctor) async {
    try {
      await _firestore
          .collection(doctorsCollection)
          .doc(doctor.id)
          .update(doctor.toFirestore());
      return true;
    } catch (e) {
      print('[ConsultationService] Error updating doctor profile: $e');
      return false;
    }
  }

  /// Create or update doctor profile (uses set+merge so first-time saves work)
  Future<bool> createOrUpdateDoctorProfile(DoctorModel doctor) async {
    try {
      await _firestore
          .collection(doctorsCollection)
          .doc(doctor.id)
          .set(doctor.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (e) {
      print('[ConsultationService] Error create/update doctor profile: $e');
      return false;
    }
  }

  /// Stream of a single doctor profile for real-time updates on user side
  Stream<DoctorModel?> getDoctorProfileStream(String doctorId) {
    return _firestore
        .collection(doctorsCollection)
        .doc(doctorId)
        .snapshots()
        .map((snap) => snap.exists ? DoctorModel.fromFirestore(snap) : null);
  }

  /// Stream of all doctors for real-time browse on user side
  Stream<List<DoctorModel>> getAllDoctorsStream() {
    return _firestore
        .collection(doctorsCollection)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => DoctorModel.fromFirestore(doc)).toList(),
        );
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
    TimeSlotModel slot,
  ) async {
    try {
      final batch = _firestore.batch();

      // 1. Create booking document
      final bookingRef = _firestore.collection(bookingsCollection).doc();
      final finalBooking = booking.copyWith(
        id: bookingRef.id,
        status: BookingStatus.requested,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print(
        '[ConsultationService] Creating booking: ${bookingRef.id} for patient: ${finalBooking.patientId}',
      );
      batch.set(bookingRef, finalBooking.toFirestore());

      // 2. Prepare slot data
      final dateKey =
          '${booking.dateTime.year}-${booking.dateTime.month.toString().padLeft(2, '0')}-${booking.dateTime.day.toString().padLeft(2, '0')}';
      print(
        '[ConsultationService] Updating slot: ${slot.id} on date: $dateKey',
      );
      final slotRef = _firestore
          .collection(slotsCollection)
          .doc(booking.doctorId)
          .collection(dateKey)
          .doc(slot.id);

      // Create or update slot status to booked
      final updatedSlot = TimeSlotModel(
        id: slot.id,
        doctorId: slot.doctorId,
        date: slot.date,
        startTime: slot.startTime,
        endTime: slot.endTime,
        status: SlotStatus.booked,
        bookingId: bookingRef.id,
      );

      batch.set(slotRef, updatedSlot.toFirestore());

      print('[ConsultationService] Committing batch...');
      await batch.commit();
      print('[ConsultationService] Batch committed successfully');
      return bookingRef.id;
    } catch (e, stack) {
      print('[ConsultationService] Error creating booking: $e');
      print(stack);
      return null;
    }
  }

  /// Get all bookings for a patient
  Future<List<ConsultationBookingModel>> getPatientBookings(
    String patientId,
  ) async {
    try {
      print('[ConsultationService] Fetching bookings for patient: $patientId');
      final querySnapshot = await _firestore
          .collection(bookingsCollection)
          .where('patientId', isEqualTo: patientId)
          // Temporarily removed to check for index issues
          // .orderBy('dateTime', descending: true)
          .get();

      print(
        '[ConsultationService] Found ${querySnapshot.docs.length} bookings',
      );
      final list = querySnapshot.docs
          .map((doc) => ConsultationBookingModel.fromFirestore(doc))
          .toList();

      // Sort in-memory to avoid index requirement during debugging
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (e, stack) {
      print('[ConsultationService] Error fetching patient bookings: $e');
      print(stack);
      return [];
    }
  }

  /// Get all bookings for a doctor
  Future<List<ConsultationBookingModel>> getDoctorBookings(
    String doctorId,
  ) async {
    try {
      print('[ConsultationService] Fetching bookings for doctor: $doctorId');
      final querySnapshot = await _firestore
          .collection(bookingsCollection)
          .where('doctorId', isEqualTo: doctorId)
          // Temporarily removed to check for index issues
          // .orderBy('dateTime', descending: true)
          .get();

      print(
        '[ConsultationService] Found ${querySnapshot.docs.length} doctor bookings',
      );
      final list = querySnapshot.docs
          .map((doc) => ConsultationBookingModel.fromFirestore(doc))
          .toList();

      // Sort in-memory
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (e, stack) {
      print('[ConsultationService] Error fetching doctor bookings: $e');
      print(stack);
      return [];
    }
  }

  /// Update booking status (confirm/reject/cancel)
  /// When cancelling, also releases the associated time slot.
  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus, {
    String? doctorNotes,
    String? zoomLink,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': newStatus.toString(),
        'updatedAt': Timestamp.now(),
      };

      if (doctorNotes != null) updates['doctorNotes'] = doctorNotes;
      if (zoomLink != null) updates['zoomLink'] = zoomLink;

      await _firestore
          .collection(bookingsCollection)
          .doc(bookingId)
          .update(updates);

      // Release the time slot when booking is cancelled/rejected
      if (newStatus == BookingStatus.cancelled) {
        final bookingSnap = await _firestore
            .collection(bookingsCollection)
            .doc(bookingId)
            .get();
        if (bookingSnap.exists) {
          final data = bookingSnap.data()!;
          final doctorId = data['doctorId'] as String;
          final dateTime = (data['dateTime'] as Timestamp).toDate();
          final timeSlot = data['timeSlot'] as String;
          await releaseSlot(doctorId, dateTime, timeSlot);
        }
      }

      return true;
    } catch (e) {
      print('[ConsultationService] Error updating booking status: $e');
      return false;
    }
  }

  /// Release a time slot back to available when a booking is cancelled
  Future<void> releaseSlot(
    String doctorId,
    DateTime date,
    String timeSlot,
  ) async {
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final querySnapshot = await _firestore
          .collection(slotsCollection)
          .doc(doctorId)
          .collection(dateKey)
          .where('startTime', isEqualTo: timeSlot)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.update({
          'status': SlotStatus.available.toString(),
          'bookingId': FieldValue.delete(),
        });
      }
      print('[ConsultationService] Slot released: $timeSlot on $dateKey');
    } catch (e) {
      print('[ConsultationService] Error releasing slot: $e');
    }
  }

  /// Auto-expire bookings that are still 'requested' past their time slot.
  /// Call this on doctor dashboard load to keep data clean.
  Future<int> autoExpireBookings(String doctorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(bookingsCollection)
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: BookingStatus.requested.toString())
          .get();

      int expiredCount = 0;
      final now = DateTime.now();
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final dateTime = (data['dateTime'] as Timestamp).toDate();
        final timeSlotStr = data['timeSlot'] as String;

        // Parse the time slot to get the actual start time
        DateTime slotDateTime;
        try {
          final parsed = DateFormat('h:mm a').parse(timeSlotStr);
          slotDateTime = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            parsed.hour,
            parsed.minute,
          );
        } catch (_) {
          // If time parsing fails, use the date only
          slotDateTime = dateTime;
        }

        // If the slot start time has passed, auto-cancel
        if (slotDateTime.isBefore(now)) {
          batch.update(doc.reference, {
            'status': BookingStatus.cancelled.toString(),
            'doctorNotes': 'Auto-cancelled: not accepted before time slot',
            'updatedAt': Timestamp.now(),
          });

          // Release the slot too
          await releaseSlot(doctorId, dateTime, timeSlotStr);
          expiredCount++;
        }
      }

      if (expiredCount > 0) {
        await batch.commit();
        print('[ConsultationService] Auto-expired $expiredCount bookings');
      }
      return expiredCount;
    } catch (e) {
      print('[ConsultationService] Error auto-expiring bookings: $e');
      return 0;
    }
  }

  /// Real-time stream of bookings for a doctor
  Stream<List<ConsultationBookingModel>> getDoctorBookingsStream(
    String doctorId,
  ) {
    return _firestore
        .collection(bookingsCollection)
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => ConsultationBookingModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return list;
        });
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

  /// Delete a booking record
  Future<bool> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection(bookingsCollection).doc(bookingId).delete();
      return true;
    } catch (e) {
      print('[ConsultationService] Error deleting booking: $e');
      return false;
    }
  }
}
