import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore service for music likes and user playlists
class MusicService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════
  // LIKES
  // ═══════════════════════════════════════════

  /// Get like count for a track
  Future<int> getLikeCount(String trackId) async {
    try {
      final doc = await _firestore.collection('music_likes').doc(trackId).get();
      if (doc.exists) {
        return (doc.data()?['likeCount'] ?? 0) as int;
      }
      return 0;
    } catch (e) {
      debugPrint('[MusicService] Error getting like count: $e');
      return 0;
    }
  }

  /// Get all like counts at once
  Future<Map<String, int>> getAllLikeCounts() async {
    try {
      final snapshot = await _firestore.collection('music_likes').get();
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        counts[doc.id] = (doc.data()['likeCount'] ?? 0) as int;
      }
      return counts;
    } catch (e) {
      debugPrint('[MusicService] Error getting all like counts: $e');
      return {};
    }
  }

  /// Check if user liked a track
  Future<bool> isLikedByUser(String trackId, String userId) async {
    try {
      final doc = await _firestore.collection('music_likes').doc(trackId).get();
      if (doc.exists) {
        final likedBy = List<String>.from(doc.data()?['likedByUserIds'] ?? []);
        return likedBy.contains(userId);
      }
      return false;
    } catch (e) {
      debugPrint('[MusicService] Error checking like status: $e');
      return false;
    }
  }

  /// Get all liked track IDs for a user
  Future<Set<String>> getUserLikedTrackIds(String userId) async {
    try {
      final snapshot = await _firestore.collection('music_likes').get();
      final likedIds = <String>{};
      for (final doc in snapshot.docs) {
        final likedBy = List<String>.from(doc.data()['likedByUserIds'] ?? []);
        if (likedBy.contains(userId)) {
          likedIds.add(doc.id);
        }
      }
      return likedIds;
    } catch (e) {
      debugPrint('[MusicService] Error getting user liked tracks: $e');
      return {};
    }
  }

  /// Toggle like on a track
  Future<bool> toggleLike(String trackId, String userId) async {
    try {
      final docRef = _firestore.collection('music_likes').doc(trackId);
      final doc = await docRef.get();

      if (doc.exists) {
        final likedBy = List<String>.from(doc.data()?['likedByUserIds'] ?? []);
        final isLiked = likedBy.contains(userId);

        if (isLiked) {
          // Unlike
          await docRef.update({
            'likeCount': FieldValue.increment(-1),
            'likedByUserIds': FieldValue.arrayRemove([userId]),
          });
          return false;
        } else {
          // Like
          await docRef.update({
            'likeCount': FieldValue.increment(1),
            'likedByUserIds': FieldValue.arrayUnion([userId]),
          });
          return true;
        }
      } else {
        // First like on this track
        await docRef.set({
          'likeCount': 1,
          'likedByUserIds': [userId],
        });
        return true;
      }
    } catch (e) {
      debugPrint('[MusicService] Error toggling like: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // PLAYLISTS
  // ═══════════════════════════════════════════

  /// Get all playlists for a user
  Future<List<MusicPlaylist>> getUserPlaylists(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('music_playlists')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MusicPlaylist.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[MusicService] Error getting playlists: $e');
      return [];
    }
  }

  /// Create a new playlist
  Future<String?> createPlaylist(
    String userId,
    String name, {
    List<String> trackIds = const [],
  }) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('music_playlists')
          .add({
            'name': name,
            'trackIds': trackIds,
            'createdAt': FieldValue.serverTimestamp(),
          });
      return docRef.id;
    } catch (e) {
      debugPrint('[MusicService] Error creating playlist: $e');
      return null;
    }
  }

  /// Add a track to a playlist
  Future<void> addToPlaylist(
    String userId,
    String playlistId,
    String trackId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('music_playlists')
          .doc(playlistId)
          .update({
            'trackIds': FieldValue.arrayUnion([trackId]),
          });
    } catch (e) {
      debugPrint('[MusicService] Error adding to playlist: $e');
    }
  }

  /// Remove a track from a playlist
  Future<void> removeFromPlaylist(
    String userId,
    String playlistId,
    String trackId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('music_playlists')
          .doc(playlistId)
          .update({
            'trackIds': FieldValue.arrayRemove([trackId]),
          });
    } catch (e) {
      debugPrint('[MusicService] Error removing from playlist: $e');
    }
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String userId, String playlistId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('music_playlists')
          .doc(playlistId)
          .delete();
    } catch (e) {
      debugPrint('[MusicService] Error deleting playlist: $e');
    }
  }

  /// Rename a playlist
  Future<void> renamePlaylist(
    String userId,
    String playlistId,
    String newName,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('music_playlists')
          .doc(playlistId)
          .update({'name': newName});
    } catch (e) {
      debugPrint('[MusicService] Error renaming playlist: $e');
    }
  }
}

/// Playlist model for Firestore data
class MusicPlaylist {
  final String id;
  final String name;
  final List<String> trackIds;
  final DateTime createdAt;

  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
  });

  factory MusicPlaylist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MusicPlaylist(
      id: doc.id,
      name: data['name'] ?? 'Untitled',
      trackIds: List<String>.from(data['trackIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  MusicPlaylist copyWith({String? name, List<String>? trackIds}) {
    return MusicPlaylist(
      id: id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt,
    );
  }
}
