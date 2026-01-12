import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories.dart';
import 'models.dart';

class AuthViewModel with ChangeNotifier {
  final AuthRepository _repo = AuthRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _userSub;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthViewModel() {
    _auth.authStateChanges().listen((firebaseUser) {
      debugPrint("Auth 상태 변경: ${firebaseUser?.uid}");
      _user = firebaseUser;
      
      _userSub?.cancel();

      if (firebaseUser != null) {
        _userSub = _repo.userStream(firebaseUser.uid).listen((updatedUser) {
          _userModel = updatedUser;
          notifyListeners();
        }, onError: (e) {
          debugPrint("유저 스트림 에러: $e");
        });
      } else {
        _userModel = null;
        notifyListeners();
      }
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _parseFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return '이미 가입된 이메일입니다.';
      case 'weak-password': return '비밀번호는 6자리 이상이어야 합니다.';
      case 'invalid-email': return '유효하지 않은 이메일 형식입니다.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return '비밀번호가 틀렸습니다.'; // '이메일 또는' 제거
      case 'too-many-requests': return '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
      case 'requires-recent-login': return '보안을 위해 다시 로그인한 후 시도해 주세요.';
      default: return '오류가 발생했습니다: ${e.message}';
    }
  }

  Future<void> fetchUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      final model = await _repo.getUser(currentUser.uid);
      if (model != null) {
        _userModel = model;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("프로필 로드 실패: $e");
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      _errorMessage = '로그인 중 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String nickname) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      final newUser = UserModel(
        uid: uid,
        email: email,
        nickname: nickname,
        isLocationPublic: true,
        createdAt: DateTime.now(),
        stats: UserStats(),
      );

      try {
        await _repo.saveUserWithNicknameCheck(newUser);
      } catch (e) {
        await userCredential.user?.delete();
        rethrow;
      }

      await userCredential.user!.updateDisplayName(nickname);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      _errorMessage = '이메일 전송 중 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _userSub?.cancel();
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }

  Future<bool> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
      return false;
    } catch (e) {
      _errorMessage = '인증에 실패했습니다.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final uid = user.uid;
      final batch = _db.batch();

      final walks = await _db.collection('walks').where('userId', isEqualTo: uid).get();
      for (var doc in walks.docs) { batch.delete(doc.reference); }

      final pets = await _db.collection('pets').where('ownerId', isEqualTo: uid).get();
      for (var doc in pets.docs) { batch.delete(doc.reference); }

      final notifications = await _db.collection('notifications').where('userId', isEqualTo: uid).get();
      for (var doc in notifications.docs) { batch.delete(doc.reference); }

      if (_userModel != null) {
        batch.delete(_db.collection('usernames').doc(_userModel!.nickname));
      }

      batch.delete(_db.collection('users').doc(uid));

      await batch.commit();
      await user.delete();
      
      _userModel = null;
      _userSub?.cancel();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
      if (e.code == 'requires-recent-login') {
        _errorMessage = '보안을 위해 다시 로그인한 후 탈퇴를 진행해 주세요.';
      }
    } catch (e) {
      _errorMessage = '회원 탈퇴 중 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
