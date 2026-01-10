import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories.dart';
import 'models.dart';

//원복
class AuthViewModel with ChangeNotifier {
  final AuthRepository _repo = AuthRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      _user = firebaseUser;

      _userSub?.cancel();

      if (firebaseUser != null) {
        _userSub = _repo.userStream(firebaseUser.uid).listen((updatedUser) {
          _userModel = updatedUser;
          notifyListeners();
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
      case 'invalid-credential': return '이메일 또는 비밀번호가 틀렸습니다.';
      case 'too-many-requests': return '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
      case 'requires-recent-login': return '보안을 위해 다시 로그인한 후 시도해 주세요.';
      default: return '오류가 발생했습니다: ${e.message}';
    }
  }

  Future<void> fetchUserProfile() async {
    if (_user == null) return;
    try {
      _userModel = await _repo.getUser(_user!.uid);
      notifyListeners();
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
    await _auth.signOut();
    _userModel = null;
    _userSub?.cancel();
    notifyListeners();
  }

  // 비밀번호 재인증 (보안 작업 전 확인)
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

  // 회원 탈퇴 기능 추가
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Firestore 유저 데이터 삭제
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

      // 2. Firebase Auth 계정 삭제
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
