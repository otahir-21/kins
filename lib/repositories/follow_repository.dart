import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Lightweight user info for follower/following lists.
class FollowUserInfo {
  final String uid;
  final String? name;
  final String? profilePictureUrl;

  FollowUserInfo({required this.uid, this.name, this.profilePictureUrl});
}

/// Follow/unfollow, counts, and lists stored in Firestore:
/// - users/{uid}/following/{targetUid} — I follow them
/// - users/{uid}/followers/{followerUid} — they follow me
/// - users/{uid}.followerCount, followingCount — maintained on follow/unfollow
class FollowRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Follow target user. Caller must be current user uid.
  Future<void> follow({required String currentUid, required String targetUid}) async {
    if (currentUid == targetUid) return;
    final batch = _firestore.batch();
    final currentRef = _firestore.collection('users').doc(currentUid);
    final targetRef = _firestore.collection('users').doc(targetUid);

    batch.set(
      _firestore.collection('users').doc(currentUid).collection('following').doc(targetUid),
      {'addedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.collection('users').doc(targetUid).collection('followers').doc(currentUid),
      {'addedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    batch.update(currentRef, {'followingCount': FieldValue.increment(1)});
    batch.update(targetRef, {'followerCount': FieldValue.increment(1)});
    await batch.commit();
    debugPrint('✅ Follow: $currentUid -> $targetUid');
  }

  /// Unfollow target user.
  Future<void> unfollow({required String currentUid, required String targetUid}) async {
    if (currentUid == targetUid) return;
    final batch = _firestore.batch();
    final currentRef = _firestore.collection('users').doc(currentUid);
    final targetRef = _firestore.collection('users').doc(targetUid);

    batch.delete(_firestore.collection('users').doc(currentUid).collection('following').doc(targetUid));
    batch.delete(_firestore.collection('users').doc(targetUid).collection('followers').doc(currentUid));
    batch.update(currentRef, {'followingCount': FieldValue.increment(-1)});
    batch.update(targetRef, {'followerCount': FieldValue.increment(-1)});
    await batch.commit();
    debugPrint('✅ Unfollow: $currentUid -> $targetUid');
  }

  /// Remove a follower (they stop following me). Call with currentUid = me, followerUid = them.
  Future<void> removeFollower({required String currentUid, required String followerUid}) async {
    if (currentUid == followerUid) return;
    // Equivalent to followerUid unfollowing currentUid
    return unfollow(currentUid: followerUid, targetUid: currentUid);
  }

  /// Get follower count from user document (cached field).
  Future<int> getFollowerCount(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final n = doc.data()?['followerCount'];
    if (n == null) return 0;
    if (n is int) return n.clamp(0, 0x7fffffff);
    return 0;
  }

  /// Get following count from user document.
  Future<int> getFollowingCount(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final n = doc.data()?['followingCount'];
    if (n == null) return 0;
    if (n is int) return n.clamp(0, 0x7fffffff);
    return 0;
  }

  /// Stream follower count (for profile).
  Stream<int> streamFollowerCount(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final n = doc.data()?['followerCount'];
      if (n is int) return n.clamp(0, 0x7fffffff);
      return 0;
    });
  }

  /// Stream following count (for profile).
  Stream<int> streamFollowingCount(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final n = doc.data()?['followingCount'];
      if (n is int) return n.clamp(0, 0x7fffffff);
      return 0;
    });
  }

  /// Check if current user follows target.
  Future<bool> isFollowing({required String currentUid, required String targetUid}) async {
    if (currentUid == targetUid) return false;
    final doc = await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  /// Resolve a list of user IDs to [FollowUserInfo] (name, photo) from users collection.
  Future<List<FollowUserInfo>> _resolveUserIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final out = <FollowUserInfo>[];
    for (final uid in uids) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final d = doc.data();
      final name = d?['name'] as String?;
      final photo = d?['profilePictureUrl'] ?? d?['profilePicture'];
      out.add(FollowUserInfo(uid: uid, name: name, profilePictureUrl: photo is String ? photo : null));
    }
    return out;
  }

  /// Stream list of followers (user ids then resolved to info).
  Stream<List<FollowUserInfo>> streamFollowers(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((d) => d.id).toList();
      return _resolveUserIds(ids);
    });
  }

  /// Stream list of following (user ids then resolved to info).
  Stream<List<FollowUserInfo>> streamFollowing(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((d) => d.id).toList();
      return _resolveUserIds(ids);
    });
  }
}
