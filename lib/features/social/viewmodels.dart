import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart'; // 통합 리포지토리 import
import '../auth/models.dart';         // 유저 모델 import
import 'package:cloud_firestore/cloud_firestore.dart';

class SocialViewModel with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final SocialRepository _repo = SocialRepository();

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  Set<String> _followingIds = {};
  Set<String> _blockedIds = {};
  List<UserModel> _blockedUserList = [];

  // 현재 검색어 상태 저장 (팔로우 토글 시 리스트 유지를 위함)
  String _currentSearchQuery = '';

  List<UserModel> get users => _filteredUsers;
  List<UserModel> get blockedUserList => _blockedUserList;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SocialViewModel() {
    fetchUsers();
  }

  Future<void> toggleLike({
    required String walkId,
    required String ownerId,
    required String myNickname,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final walkRef = FirebaseFirestore.instance.collection('walks').doc(walkId);
    final likeRef = walkRef.collection('likes').doc(myUid);
    final notificationRef = FirebaseFirestore.instance.collection('notifications');

    // 1. 현재 좋아요 상태 확인
    final likeDoc = await likeRef.get();
    final isAdding = !likeDoc.exists;

    try {
      if (isAdding) {
        // 좋아요 추가
        await likeRef.set({
          'nickname': myNickname,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // walk 문서의 likeCount 업데이트 (이미지 구조에 맞춰서)
        await walkRef.update({'likeCount': FieldValue.increment(1)});

        // 알림 추가 (이미지_281956.png 구조 참고)
        await notificationRef.add({
          'body': "회원님의 산책 기록을 좋아합니다.",
          'createdAt': FieldValue.serverTimestamp(),
          'fromUserId': myUid,
          'fromUserNickname': myNickname,
          'postId': walkId,
          'read': false,
          'title': "$myNickname님이 내 기록을 좋아합니다.",
          'type': "like",
          'userId': ownerId, // 게시물 주인 ID
        });
      } else {
        // 좋아요 취소
        await likeRef.delete();
        await walkRef.update({'likeCount': FieldValue.increment(-1)});

        // (옵션) 좋아요 취소 시 기존 알림을 삭제하고 싶다면 추가 로직 필요
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Like Toggle Error: $e");
      rethrow;
    }
  }

  Future<void> fetchUsers() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _allUsers = await _repo.getAllUsers(myUid);
      _followingIds = await _repo.getMyFollowingIds(myUid);
      _blockedIds = await _repo.getBlockedUserIds(myUid);
      
      _applyFilter();
    } catch (e) {
      print("Social Data Load Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 차단된 유저 상세 목록 불러오기 (설정 화면용)
  Future<void> fetchBlockedUsers() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      _blockedUserList = await _repo.getBlockedUsers(myUid);
    } catch (e) {
      debugPrint("Fetch Blocked Users Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 필터링 로직 (차단된 유저는 검색에서 제외)
  void _applyFilter() {
    var baseUsers = _allUsers.where((u) => !_blockedIds.contains(u.uid));

    if (_currentSearchQuery.isEmpty) {
      _filteredUsers = baseUsers.where((user) => _followingIds.contains(user.uid)).toList();
    } else {
      _filteredUsers = baseUsers.where((user) =>
          user.nickname.toLowerCase().contains(_currentSearchQuery.toLowerCase())).toList();
    }
  }

  void searchUsers(String query) {
    _currentSearchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  Future<void> toggleFollow(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final isFollowing = _followingIds.contains(targetUid);

    if (isFollowing) {
      _followingIds.remove(targetUid);
    } else {
      _followingIds.add(targetUid);
    }

    _applyFilter();
    notifyListeners();

    try {
      if (isFollowing) {
        await _repo.unfollowUser(myUid: myUid, targetUid: targetUid);
      } else {
        await _repo.followUser(myUid: myUid, targetUid: targetUid);
      }
    } catch (e) {
      if (isFollowing) {
        _followingIds.add(targetUid);
      } else {
        _followingIds.remove(targetUid);
      }
      _applyFilter();
      notifyListeners();
      rethrow;
    }
  }

  // 차단 실행/해제 (프로필에서 호출)
  Future<void> toggleBlock(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    if (_blockedIds.contains(targetUid)) {
      await unblockUser(targetUid);
    } else {
      await _repo.blockUser(myUid: myUid, targetUid: targetUid);
      _blockedIds.add(targetUid);
      _followingIds.remove(targetUid); // 차단 시 팔로우 해제 반영
      _applyFilter();
      notifyListeners();
    }
  }

  // 차단 해제 전용 (설정 화면 등에서 사용)
  Future<void> unblockUser(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      await _repo.unblockUser(myUid: myUid, targetUid: targetUid);
      _blockedIds.remove(targetUid);
      _blockedUserList.removeWhere((u) => u.uid == targetUid);
      _applyFilter();
      notifyListeners();
    } catch (e) {
      debugPrint("Unblock Error: $e");
    }
  }

  bool isFollowing(String uid) => _followingIds.contains(uid);
  bool isBlocked(String uid) => _blockedIds.contains(uid);

  // [추가] 좋아요 누른 사람들 목록 가져오기 UI 반영
  Future<List<Map<String, dynamic>>> getLikers(String walkId) async {
    final snapshot = await _db.collection('walks').doc(walkId).collection('likes').get();
    List<Map<String, dynamic>> likers = [];

    for (var doc in snapshot.docs) {
      final userDoc = await _db.collection('users').doc(doc.id).get();
      if (userDoc.exists) {
        likers.add({
          'uid': doc.id,
          'nickname': userDoc.data()?['nickname'] ?? '익명',
          'profileImageUrl': userDoc.data()?['profileImageUrl'] ?? '',
          'email': userDoc.data()?['email'] ?? '',
        });
      }
    }
    return likers;
  }
}