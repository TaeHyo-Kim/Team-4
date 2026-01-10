import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart'; // 통합 리포지토리 import
import '../auth/models.dart';         // 유저 모델 import

class SocialViewModel with ChangeNotifier {
  final SocialRepository _repo = SocialRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
