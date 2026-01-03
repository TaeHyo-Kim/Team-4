import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart'; // 통합 리포지토리 import
import '../auth/models.dart';         // 유저 모델 import

class SocialViewModel with ChangeNotifier {
  final SocialRepository _repo = SocialRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. 전체 유저 데이터 (원본)
  List<UserModel> _allUsers = [];

  // 2. 화면에 보여줄 유저 데이터 (검색 필터 적용됨)
  List<UserModel> _filteredUsers = [];

  // 3. 내가 팔로우한 사람들의 ID 목록 (빠른 조회를 위해 Set 사용)
  Set<String> _followingIds = {};

  // Getter
  List<UserModel> get users => _filteredUsers;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 생성자: 뷰모델 생성 시 바로 데이터 로드
  SocialViewModel() {
    fetchUsers();
  }

  // 데이터 불러오기 (전체 유저 + 내 팔로잉 목록)
  Future<void> fetchUsers() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    _isLoading = true;
    // (옵션) 화면 깜빡임 방지를 위해 로딩 중엔 notifyListeners 생략 가능,
    // 여기선 로딩 표시를 위해 호출함
    notifyListeners();

    try {
      // 1. 나를 제외한 모든 유저 가져오기
      _allUsers = await _repo.getAllUsers(myUid);
      _filteredUsers = List.from(_allUsers); // 초기엔 전체 복사

      // 2. 내가 팔로우 중인 ID 목록 가져오기
      _followingIds = await _repo.getMyFollowingIds(myUid);

    } catch (e) {
      print("Social Data Load Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 검색 기능 (로컬 필터링)
  void searchUsers(String query) {
    if (query.isEmpty) {
      _filteredUsers = List.from(_allUsers);
    } else {
      _filteredUsers = _allUsers.where((user) {
        return user.nickname.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  // 팔로우 / 언팔로우 토글
  Future<void> toggleFollow(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    // 현재 팔로우 중인지 확인
    final isFollowing = _followingIds.contains(targetUid);

    // 낙관적 업데이트 (Optimistic Update):
    // 서버 응답 기다리기 전에 UI 먼저 바꿈 -> 앱이 빨라 보임
    if (isFollowing) {
      _followingIds.remove(targetUid);
    } else {
      _followingIds.add(targetUid);
    }
    notifyListeners();

    try {
      if (isFollowing) {
        await _repo.unfollowUser(myUid: myUid, targetUid: targetUid);
      } else {
        await _repo.followUser(myUid: myUid, targetUid: targetUid);
      }
    } catch (e) {
      print("Follow Error: $e");
      // 실패하면 UI 원복
      if (isFollowing) {
        _followingIds.add(targetUid);
      } else {
        _followingIds.remove(targetUid);
      }
      notifyListeners();
      rethrow; // View에서 에러 메시지를 띄울 수 있게 던짐
    }
  }

  // UI 헬퍼: 특정 유저를 내가 팔로우 중인가?
  bool isFollowing(String uid) => _followingIds.contains(uid);
}