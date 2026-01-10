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
      debugPrint("산책 기록 로드 실패: $e");
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

      // 1. 이미지가 있으면 스토리지에 업로드
      if (imageFile != null) {
        final ref = _storage.ref().child('profiles/$uid/profile.png');
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }

      // 2. Firestore 업데이트 데이터 구성
      final updates = {
        'nickname': nickname,
        'bio': bio,
      };
      if (imageUrl != null) {
        updates['profileImageUrl'] = imageUrl;
      }

      // 3. DB 반영
      await _db.collection('users').doc(uid).update(updates);
      
    } catch (e) {
      debugPrint("프로필 업데이트 실패: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 기존 메서드 유지 (필요시 사용)
  Future<void> updateProfileInfo(String nickname, String bio) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'nickname': nickname,
        'bio': bio,
      });
    } catch (e) {
      rethrow;
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
