import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../auth/models.dart';
import '../walk/models.dart';
import '../../data/repositories.dart';

class ProfileViewModel with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SocialRepository _socialRepo = SocialRepository();

  List<WalkRecordModel> _walkRecords = [];
  List<WalkRecordModel> get walkRecords => _walkRecords;

  List<WalkRecordModel> _otherUserWalkRecords = [];
  List<WalkRecordModel> get otherUserWalkRecords => _otherUserWalkRecords;

  List<UserModel> _followingUsers = [];
  List<UserModel> _followerUsers = [];

  List<UserModel> get followingUsers => _followingUsers;
  List<UserModel> get followerUsers => _followerUsers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 내 산책 기록 로드
  Future<void> fetchMyWalkRecords() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _db.collection('walks')
          .where('userId', isEqualTo: uid)
          .orderBy('startTime', descending: true)
          .get();

      _walkRecords = snapshot.docs.map((doc) => WalkRecordModel.fromDocument(doc)).toList();
    } catch (e) {
      debugPrint("내 산책 기록 로드 실패: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 다른 사용자의 산책 기록 로드
  Future<void> fetchOtherUserWalks(String userId) async {
    _isLoading = true;
    _otherUserWalkRecords = [];
    notifyListeners();

    try {
      final snapshot = await _db.collection('walks')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .get();

      _otherUserWalkRecords = snapshot.docs.map((doc) => WalkRecordModel.fromDocument(doc)).toList();
    } catch (e) {
      debugPrint("다른 사용자 산책 기록 로드 실패: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 프로필 업데이트 통합 메서드 (닉네임, 한줄소개, 이미지)
  Future<void> updateProfile({
    required String nickname,
    required String bio,
    File? imageFile,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      String? imageUrl;

      if (imageFile != null) {
        final ref = _storage.ref().child('profiles/$uid/profile.png');
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }

      final updates = {
        'nickname': nickname,
        'bio': bio,
      };
      if (imageUrl != null) {
        updates['profileImageUrl'] = imageUrl;
      }

      await _db.collection('users').doc(uid).update(updates);

    } catch (e) {
      debugPrint("프로필 업데이트 실패: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 팔로잉 목록 가져오기
  Future<void> fetchFollowingUsers(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _followingUsers = await _socialRepo.getFollowingUsers(userId);
    } catch (e) {
      debugPrint("팔로잉 목록 로드 실패: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 팔로워 목록 가져오기
  Future<void> fetchFollowerUsers(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _followerUsers = await _socialRepo.getFollowerUsers(userId);
    } catch (e) {
      debugPrint("팔로워 목록 로드 실패: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
