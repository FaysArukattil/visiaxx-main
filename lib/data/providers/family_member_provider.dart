import 'package:flutter/foundation.dart';
import '../../core/services/family_member_service.dart';
import '../models/family_member_model.dart';

/// Provider for managing family members with caching and background loading
class FamilyMemberProvider with ChangeNotifier {
  final FamilyMemberService _familyMemberService = FamilyMemberService();

  List<FamilyMemberModel> _familyMembers = [];
  bool _isLoading = false;
  String? _error;
  bool _hasInitialLoad = false;

  // Getters
  List<FamilyMemberModel> get familyMembers => _familyMembers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasInitialLoad => _hasInitialLoad;

  /// Load family members with background refresh logic
  Future<void> loadFamilyMembers(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (_hasInitialLoad && !forceRefresh) {
      // Refresh in background if already has data
      _getBackgroundRefresh(userId);
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final members = await _familyMemberService.getFamilyMembers(userId);
      _familyMembers = members;
      _hasInitialLoad = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[FamilyMemberProvider] Error loading family members: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Perform a background refresh without showing loading state
  Future<void> _getBackgroundRefresh(String userId) async {
    try {
      final members = await _familyMemberService.getFamilyMembers(userId);

      // Only notify if data actually changed
      if (_hasChanges(members)) {
        _familyMembers = members;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[FamilyMemberProvider] Background refresh error: $e');
    }
  }

  bool _hasChanges(List<FamilyMemberModel> newList) {
    if (newList.length != _familyMembers.length) return true;
    for (int i = 0; i < newList.length; i++) {
      if (newList[i].id != _familyMembers[i].id ||
          newList[i].firstName != _familyMembers[i].firstName ||
          newList[i].age != _familyMembers[i].age) {
        return true;
      }
    }
    return false;
  }

  /// Add a new member to cache instantly (Optimistic UI)
  void addOptimistic(FamilyMemberModel member) {
    _familyMembers.insert(0, member);
    notifyListeners();
  }

  /// Update a member in cache instantly
  void updateOptimistic(FamilyMemberModel member) {
    final index = _familyMembers.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      _familyMembers[index] = member;
      notifyListeners();
    }
  }

  /// Remove a member from cache instantly
  void removeOptimistic(String id) {
    _familyMembers.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  /// Clear the cache on logout
  void clear() {
    _familyMembers = [];
    _hasInitialLoad = false;
    _error = null;
    notifyListeners();
  }
}
