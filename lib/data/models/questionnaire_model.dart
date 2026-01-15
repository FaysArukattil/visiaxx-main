import 'package:cloud_firestore/cloud_firestore.dart';

/// Pre-test questionnaire model with dynamic follow-up questions
class QuestionnaireModel {
  final String id;
  final String profileId;
  final String profileType; // 'self' or 'family'
  final DateTime timestamp;
  final ChiefComplaints chiefComplaints;
  final SystemicIllness systemicIllness;
  final String? currentMedications;
  final bool hasRecentSurgery;
  final String? surgeryDetails;

  QuestionnaireModel({
    required this.id,
    required this.profileId,
    required this.profileType,
    required this.timestamp,
    required this.chiefComplaints,
    required this.systemicIllness,
    this.currentMedications,
    this.hasRecentSurgery = false,
    this.surgeryDetails,
  });

  factory QuestionnaireModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionnaireModel.fromMap(data, doc.id);
  }

  /// Create from a Map (used when parsing nested data)
  factory QuestionnaireModel.fromMap(Map<String, dynamic> data, [String? id]) {
    return QuestionnaireModel(
      id: id ?? data['id'] ?? '',
      profileId: data['profileId'] ?? '',
      profileType: data['profileType'] ?? 'self',
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : (data['timestamp'] != null
                ? DateTime.parse(data['timestamp'].toString())
                : DateTime.now()),
      chiefComplaints: ChiefComplaints.fromMap(data['chiefComplaints'] ?? {}),
      systemicIllness: SystemicIllness.fromMap(data['systemicIllness'] ?? {}),
      currentMedications: data['currentMedications'],
      hasRecentSurgery: data['hasRecentSurgery'] ?? false,
      surgeryDetails: data['surgeryDetails'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'profileId': profileId,
      'profileType': profileType,
      'timestamp': Timestamp.fromDate(timestamp),
      'chiefComplaints': chiefComplaints.toMap(),
      'systemicIllness': systemicIllness.toMap(),
      'currentMedications': currentMedications,
      'hasRecentSurgery': hasRecentSurgery,
      'surgeryDetails': surgeryDetails,
    };
  }
}

/// Chief complaints with dynamic follow-up answers
class ChiefComplaints {
  // Main complaints
  final bool hasRedness;
  final bool hasWatering;
  final bool hasItching;
  final bool hasHeadache;
  final bool hasDryness;
  final bool hasStickyDischarge;
  final bool hasLightSensitivity;
  final bool hasPreviousCataractOperation;
  final bool hasFamilyGlaucomaHistory;

  // Follow-up answers
  final RednesFollowUp? rednessFollowUp;
  final WateringFollowUp? wateringFollowUp;
  final ItchingFollowUp? itchingFollowUp;
  final HeadacheFollowUp? headacheFollowUp;
  final DrynessFollowUp? drynessFollowUp;
  final DischargeFollowUp? dischargeFollowUp;
  final LightSensitivityFollowUp? lightSensitivityFollowUp;

  ChiefComplaints({
    this.hasRedness = false,
    this.hasWatering = false,
    this.hasItching = false,
    this.hasHeadache = false,
    this.hasDryness = false,
    this.hasStickyDischarge = false,
    this.hasPreviousCataractOperation = false,
    this.hasFamilyGlaucomaHistory = false,
    this.hasLightSensitivity = false,
    this.rednessFollowUp,
    this.wateringFollowUp,
    this.itchingFollowUp,
    this.headacheFollowUp,
    this.drynessFollowUp,
    this.dischargeFollowUp,
    this.lightSensitivityFollowUp,
  });

  factory ChiefComplaints.fromMap(Map<String, dynamic> data) {
    return ChiefComplaints(
      hasRedness: data['hasRedness'] ?? false,
      hasWatering: data['hasWatering'] ?? false,
      hasItching: data['hasItching'] ?? false,
      hasHeadache: data['hasHeadache'] ?? false,
      hasDryness: data['hasDryness'] ?? false,
      hasStickyDischarge: data['hasStickyDischarge'] ?? false,
      hasLightSensitivity: data['hasLightSensitivity'] ?? false,
      hasPreviousCataractOperation:
          data['hasPreviousCataractOperation'] ?? false,
      hasFamilyGlaucomaHistory: data['hasFamilyGlaucomaHistory'] ?? false,
      rednessFollowUp: data['rednessFollowUp'] != null
          ? RednesFollowUp.fromMap(data['rednessFollowUp'])
          : null,
      wateringFollowUp: data['wateringFollowUp'] != null
          ? WateringFollowUp.fromMap(data['wateringFollowUp'])
          : null,
      itchingFollowUp: data['itchingFollowUp'] != null
          ? ItchingFollowUp.fromMap(data['itchingFollowUp'])
          : null,
      headacheFollowUp: data['headacheFollowUp'] != null
          ? HeadacheFollowUp.fromMap(data['headacheFollowUp'])
          : null,
      drynessFollowUp: data['drynessFollowUp'] != null
          ? DrynessFollowUp.fromMap(data['drynessFollowUp'])
          : null,
      dischargeFollowUp: data['dischargeFollowUp'] != null
          ? DischargeFollowUp.fromMap(data['dischargeFollowUp'])
          : null,
      lightSensitivityFollowUp: data['lightSensitivityFollowUp'] != null
          ? LightSensitivityFollowUp.fromMap(data['lightSensitivityFollowUp'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasRedness': hasRedness,
      'hasWatering': hasWatering,
      'hasItching': hasItching,
      'hasHeadache': hasHeadache,
      'hasDryness': hasDryness,
      'hasStickyDischarge': hasStickyDischarge,
      'hasLightSensitivity': hasLightSensitivity,
      'hasPreviousCataractOperation': hasPreviousCataractOperation,
      'hasFamilyGlaucomaHistory': hasFamilyGlaucomaHistory,
      'rednessFollowUp': rednessFollowUp?.toMap(),
      'wateringFollowUp': wateringFollowUp?.toMap(),
      'itchingFollowUp': itchingFollowUp?.toMap(),
      'headacheFollowUp': headacheFollowUp?.toMap(),
      'drynessFollowUp': drynessFollowUp?.toMap(),
      'dischargeFollowUp': dischargeFollowUp?.toMap(),
      'lightSensitivityFollowUp': lightSensitivityFollowUp?.toMap(),
    };
  }

  ChiefComplaints copyWith({
    bool? hasRedness,
    bool? hasWatering,
    bool? hasItching,
    bool? hasHeadache,
    bool? hasDryness,
    bool? hasStickyDischarge,
    bool? hasLightSensitivity,
    bool? hasPreviousCataractOperation,
    bool? hasFamilyGlaucomaHistory,
    RednesFollowUp? rednessFollowUp,
    WateringFollowUp? wateringFollowUp,
    ItchingFollowUp? itchingFollowUp,
    HeadacheFollowUp? headacheFollowUp,
    DrynessFollowUp? drynessFollowUp,
    DischargeFollowUp? dischargeFollowUp,
    LightSensitivityFollowUp? lightSensitivityFollowUp,
  }) {
    return ChiefComplaints(
      hasRedness: hasRedness ?? this.hasRedness,
      hasWatering: hasWatering ?? this.hasWatering,
      hasItching: hasItching ?? this.hasItching,
      hasHeadache: hasHeadache ?? this.hasHeadache,
      hasDryness: hasDryness ?? this.hasDryness,
      hasStickyDischarge: hasStickyDischarge ?? this.hasStickyDischarge,
      hasLightSensitivity: hasLightSensitivity ?? this.hasLightSensitivity,
      hasPreviousCataractOperation:
          hasPreviousCataractOperation ?? this.hasPreviousCataractOperation,
      hasFamilyGlaucomaHistory:
          hasFamilyGlaucomaHistory ?? this.hasFamilyGlaucomaHistory,
      rednessFollowUp: rednessFollowUp ?? this.rednessFollowUp,
      wateringFollowUp: wateringFollowUp ?? this.wateringFollowUp,
      itchingFollowUp: itchingFollowUp ?? this.itchingFollowUp,
      headacheFollowUp: headacheFollowUp ?? this.headacheFollowUp,
      drynessFollowUp: drynessFollowUp ?? this.drynessFollowUp,
      dischargeFollowUp: dischargeFollowUp ?? this.dischargeFollowUp,
      lightSensitivityFollowUp:
          lightSensitivityFollowUp ?? this.lightSensitivityFollowUp,
    );
  }
}

// Follow-up models
class RednesFollowUp {
  final String duration;

  RednesFollowUp({required this.duration});

  factory RednesFollowUp.fromMap(Map<String, dynamic> data) {
    return RednesFollowUp(duration: data['duration'] ?? '');
  }

  Map<String, dynamic> toMap() => {'duration': duration};
}

class WateringFollowUp {
  final int days;
  final String pattern; // 'continuous' or 'intermittent'

  WateringFollowUp({required this.days, required this.pattern});

  factory WateringFollowUp.fromMap(Map<String, dynamic> data) {
    return WateringFollowUp(
      days: data['days'] ?? 0,
      pattern: data['pattern'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'days': days, 'pattern': pattern};
}

class ItchingFollowUp {
  final bool bothEyes;
  final String location;

  ItchingFollowUp({required this.bothEyes, required this.location});

  factory ItchingFollowUp.fromMap(Map<String, dynamic> data) {
    return ItchingFollowUp(
      bothEyes: data['bothEyes'] ?? false,
      location: data['location'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'bothEyes': bothEyes, 'location': location};
}

class HeadacheFollowUp {
  final String location;
  final String duration;
  final String painType; // 'throbbing' or 'mild'

  HeadacheFollowUp({
    required this.location,
    required this.duration,
    required this.painType,
  });

  factory HeadacheFollowUp.fromMap(Map<String, dynamic> data) {
    return HeadacheFollowUp(
      location: data['location'] ?? '',
      duration: data['duration'] ?? '',
      painType: data['painType'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'location': location,
    'duration': duration,
    'painType': painType,
  };
}

class DrynessFollowUp {
  final bool acBlowingOnFace;
  final int screenTimeHours;

  DrynessFollowUp({
    required this.acBlowingOnFace,
    required this.screenTimeHours,
  });

  factory DrynessFollowUp.fromMap(Map<String, dynamic> data) {
    return DrynessFollowUp(
      acBlowingOnFace: data['acBlowingOnFace'] ?? false,
      screenTimeHours: data['screenTimeHours'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'acBlowingOnFace': acBlowingOnFace,
    'screenTimeHours': screenTimeHours,
  };
}

class DischargeFollowUp {
  final String color; // 'white', 'green', 'yellow'
  final bool isRegular;
  final String startDate;

  DischargeFollowUp({
    required this.color,
    required this.isRegular,
    required this.startDate,
  });

  factory DischargeFollowUp.fromMap(Map<String, dynamic> data) {
    return DischargeFollowUp(
      color: data['color'] ?? '',
      isRegular: data['isRegular'] ?? false,
      startDate: data['startDate'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'color': color,
    'isRegular': isRegular,
    'startDate': startDate,
  };
}

class LightSensitivityFollowUp {
  final bool isSevere;
  final String details;

  LightSensitivityFollowUp({required this.isSevere, required this.details});

  factory LightSensitivityFollowUp.fromMap(Map<String, dynamic> data) {
    return LightSensitivityFollowUp(
      isSevere: data['isSevere'] ?? false,
      details: data['details'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'isSevere': isSevere, 'details': details};
}

/// Systemic illness tracking
class SystemicIllness {
  final bool hasHypertension;
  final bool hasDiabetes;
  final bool hasCopd;
  final bool hasAsthma;
  final bool hasMigraine;
  final bool hasSinus;

  SystemicIllness({
    this.hasHypertension = false,
    this.hasDiabetes = false,
    this.hasCopd = false,
    this.hasAsthma = false,
    this.hasMigraine = false,
    this.hasSinus = false,
  });

  factory SystemicIllness.fromMap(Map<String, dynamic> data) {
    return SystemicIllness(
      hasHypertension: data['hasHypertension'] ?? false,
      hasDiabetes: data['hasDiabetes'] ?? false,
      hasCopd: data['hasCopd'] ?? false,
      hasAsthma: data['hasAsthma'] ?? false,
      hasMigraine: data['hasMigraine'] ?? false,
      hasSinus: data['hasSinus'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasHypertension': hasHypertension,
      'hasDiabetes': hasDiabetes,
      'hasCopd': hasCopd,
      'hasAsthma': hasAsthma,
      'hasMigraine': hasMigraine,
      'hasSinus': hasSinus,
    };
  }

  SystemicIllness copyWith({
    bool? hasHypertension,
    bool? hasDiabetes,
    bool? hasCopd,
    bool? hasAsthma,
    bool? hasMigraine,
    bool? hasSinus,
  }) {
    return SystemicIllness(
      hasHypertension: hasHypertension ?? this.hasHypertension,
      hasDiabetes: hasDiabetes ?? this.hasDiabetes,
      hasCopd: hasCopd ?? this.hasCopd,
      hasAsthma: hasAsthma ?? this.hasAsthma,
      hasMigraine: hasMigraine ?? this.hasMigraine,
      hasSinus: hasSinus ?? this.hasSinus,
    );
  }

  List<String> get activeConditions {
    List<String> conditions = [];
    if (hasHypertension) conditions.add('Hypertension');
    if (hasDiabetes) conditions.add('Diabetes');
    if (hasCopd) conditions.add('COPD');
    if (hasAsthma) conditions.add('Asthma');
    if (hasMigraine) conditions.add('Migraine');
    if (hasSinus) conditions.add('Sinus');
    return conditions;
  }
}
