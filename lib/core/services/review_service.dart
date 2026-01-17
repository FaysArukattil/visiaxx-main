import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user has already submitted a review
  Future<bool> hasUserReviewed(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reviewCount = prefs.getInt('review_count_$userId') ?? 0;

      debugPrint(
        '[ReviewService] ” Checking review status for $userId: $reviewCount reviews',
      );
      return reviewCount > 0;
    } catch (e) {
      debugPrint('[ReviewService] Œ Error checking review status: $e');
      return false;
    }
  }

  /// Get the number of reviews submitted by user
  Future<int> getReviewCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('review_count_$userId') ?? 0;
      debugPrint('[ReviewService] ” Review count for $userId: $count');
      return count;
    } catch (e) {
      debugPrint('[ReviewService] Œ Error getting review count: $e');
      return 0;
    }
  }

  /// Increment review count for user
  Future<void> incrementReviewCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt('review_count_$userId') ?? 0;
      await prefs.setInt('review_count_$userId', currentCount + 1);
      debugPrint(
        '[ReviewService] … Incremented review count for $userId to ${currentCount + 1}',
      );
    } catch (e) {
      debugPrint('[ReviewService] Œ Error incrementing review count: $e');
    }
  }

  /// Mark that user has reviewed (kept for backward compatibility)
  @Deprecated('Use incrementReviewCount instead')
  Future<void> markAsReviewed(String userId) async {
    await incrementReviewCount(userId);
  }

  /// Check if this is user's first test
  Future<bool> isFirstTest(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirst = prefs.getBool('first_test_completed_$userId') != true;

      debugPrint(
        '[ReviewService] ” Checking first test for $userId: $isFirst',
      );
      return isFirst;
    } catch (e) {
      debugPrint('[ReviewService] Œ Error checking first test: $e');
      return true; // Assume first test on error
    }
  }

  /// Mark first test as completed
  Future<void> markFirstTestCompleted(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_test_completed_$userId', true);
      debugPrint('[ReviewService] … Marked first test completed for $userId');
    } catch (e) {
      debugPrint('[ReviewService] Œ Error marking first test: $e');
    }
  }

  /// Save review to Firebase
  Future<String?> saveReview(ReviewModel review) async {
    try {
      debugPrint('[ReviewService] “¤ Saving review to Firebase...');

      final docRef = await _firestore
          .collection('AppReviews')
          .add(review.toFirestore());

      debugPrint('[ReviewService] … Review saved to Firebase: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[ReviewService] Œ Error saving review to Firebase: $e');
      return null;
    }
  }

  static const String supportEmail = 'vnoptocare@gmail.com';

  /// Helper function to get rating label
  String _getRatingLabel(int rating) {
    switch (rating) {
      case 5:
        return 'Excellent';
      case 4:
        return 'Very Good';
      case 3:
        return 'Good';
      case 2:
        return 'Fair';
      case 1:
        return 'Poor';
      default:
        return 'Not Rated';
    }
  }

  /// Format the email body professionally for review reports
  String formatReviewEmailBody({
    required ReviewModel review,
    required String reviewId,
  }) {
    final dateStr = DateFormat('MMMM dd, yyyy').format(review.timestamp);
    final timeStr = DateFormat('h:mm a').format(review.timestamp);
    final stars = '­' * review.rating;
    final emptyStars = '˜†' * (5 - review.rating);

    return '''
””””””””””””””””””””””””””””””””””””””””””””””””””

          ¥ VISIAXX DIGITAL EYE CLINIC
               Official Feedback Report

””””””””””””””””””””””””””””””””””””””””””””””””””


“‹ REPORT INFORMATION

Reference ID: #$reviewId
Date: $dateStr at $timeStr
Type: Customer Feedback Analysis

””””””””””””””””””””””””””””””””””””””””””””””””””


‘¤ PATIENT PROFILE

Name: ${review.userName.toUpperCase()}
Age: ${review.userAge} Years
Status: “ Verified App User
Platform: Visiaxx Mobile Application

””””””””””””””””””””””””””””””””””””””””””””””””””


­ PERFORMANCE EVALUATION

Rating: $stars$emptyStars

Score: ${review.rating}.0 / 5.0 Stars
Level: ${_getRatingLabel(review.rating)}

””””””””””””””””””””””””””””””””””””””””””””””””””


’¬ DETAILED FEEDBACK

"${review.reviewText}"

””””””””””””””””””””””””””””””””””””””””””””””””””


”’ CONFIDENTIALITY NOTICE

This report is CONFIDENTIAL and intended exclusively for 
Vision Optocare Development Team. Unauthorized access, 
distribution, or disclosure is strictly prohibited.

””””””””””””””””””””””””””””””””””””””””””””””””””


¤– SYSTEM NOTIFICATION

Generated By: Visiaxx Feedback System
Organization: Vision Optocare Private Limited
Location: Mumbai, Maharashtra, India

“§ vnoptocare@gmail.com
Œ https://visionoptocare.com/home

© 2026 Vision Optocare. All Rights Reserved.

””””””””””””””””””””””””””””””””””””””””””””””””””

                    END OF REPORT

””””””””””””””””””””””””””””””””””””””””””””””””””
''';
  }

  /// Send email notification via user's email client (Primary Method)
  Future<bool> sendEmailViaMailClient(
    ReviewModel review, {
    String? reviewId,
  }) async {
    try {
      debugPrint('[ReviewService] “§ Opening user email client...');

      final refId = reviewId ?? 'PENDING';
      final emailBody = formatReviewEmailBody(review: review, reviewId: refId);
      final subject = 'App Review - ${review.userName}';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: supportEmail,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody)}',
      );

      debugPrint('[ReviewService] “§ Launching email URI...');

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        debugPrint('[ReviewService] … Email client opened successfully');
        return true;
      } else {
        debugPrint('[ReviewService] Œ Could not launch email client');
        return false;
      }
    } catch (e) {
      debugPrint('[ReviewService] Œ Error opening email client: $e');
      return false;
    }
  }

  /// Submit review (save + email)
  Future<bool> submitReview(ReviewModel review) async {
    try {
      debugPrint('[ReviewService] š€ Starting review submission...');

      // 1. Save to Firebase (critical)
      final reviewId = await saveReview(review);
      if (reviewId == null) {
        debugPrint('[ReviewService] Œ Failed to save review to Firebase');
        return false;
      }

      // 2. Open email client for manual sending
      final emailSent = await sendEmailViaMailClient(
        review,
        reviewId: reviewId,
      );

      // 3. Update review with email status
      try {
        await _firestore.collection('AppReviews').doc(reviewId).update({
          'emailSent': emailSent,
        });
        debugPrint('[ReviewService] … Updated email status in Firebase');
      } catch (e) {
        debugPrint('[ReviewService]  ï¸ Failed to update email status: $e');
      }

      // 4. Increment review count
      await incrementReviewCount(review.userId);

      debugPrint('[ReviewService] … Review submission completed successfully');
      return true;
    } catch (e) {
      debugPrint('[ReviewService] Œ Critical error submitting review: $e');
      return false;
    }
  }

  /// Get all reviews (for admin panel or analytics)
  Future<List<ReviewModel>> getAllReviews() async {
    try {
      final snapshot = await _firestore
          .collection('AppReviews')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[ReviewService] Œ Error fetching reviews: $e');
      return [];
    }
  }

  /// Get average rating
  Future<double> getAverageRating() async {
    try {
      final reviews = await getAllReviews();
      if (reviews.isEmpty) return 0.0;

      final sum = reviews.fold<int>(0, (sum, review) => sum + review.rating);
      return sum / reviews.length;
    } catch (e) {
      debugPrint('[ReviewService] Œ Error calculating average rating: $e');
      return 0.0;
    }
  }
}

