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

  // 현재 검색어 상태 저장 (팔로우 토글 시 리스트 유지를 위함)
  String _currentSearchQuery = '';

  List<UserModel> get users => _filteredUsers;
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

      // 초기 로드 시 검색어가 없으므로 팔로잉 중인 유저만 필터링
      _applyFilter();

    } catch (e) {
      print("Social Data Load Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 검색 및 필터링 핵심 로직
  void _applyFilter() {
    if (_currentSearchQuery.isEmpty) {
      // 검색어가 없으면: 내가 팔로우한 유저만 표시
      _filteredUsers = _allUsers.where((user) {
        return _followingIds.contains(user.uid);
      }).toList();
    } else {
      // 검색어가 있으면: 전체 유저 중에서 닉네임 검색
      _filteredUsers = _allUsers.where((user) {
        return user.nickname.toLowerCase().contains(_currentSearchQuery.toLowerCase());
      }).toList();
    }
  }

  // View에서 호출하는 검색 메서드
  void searchUsers(String query) {
    _currentSearchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  Future<void> toggleFollow(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final isFollowing = _followingIds.contains(targetUid);

    // 낙관적 업데이트
    if (isFollowing) {
      _followingIds.remove(targetUid);
    } else {
      _followingIds.add(targetUid);
    }

    // 상태 변경 후 리스트 즉시 갱신 (팔로우 취소 시 리스트에서 바로 사라지게 함)
    _applyFilter();
    notifyListeners();

    try {
      if (isFollowing) {
        await _repo.unfollowUser(myUid: myUid, targetUid: targetUid);
      } else {
        await _repo.followUser(myUid: myUid, targetUid: targetUid);
      }
    } catch (e) {
      print("Follow Error: $e");
      // 에러 시 복구
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

  bool isFollowing(String uid) => _followingIds.contains(uid);
}