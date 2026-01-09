import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart';
import 'models.dart';

class AuthViewModel with ChangeNotifier {
  final AuthRepository _repo = AuthRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthViewModel() {
    _auth.authStateChanges().listen((firebaseUser) async {
      _user = firebaseUser;
      if (firebaseUser != null) {
        await _fetchUserProfile();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // [중요] 영문 에러 코드를 한국어 메시지로 변환 [cite: 2025-07-25]
  String _parseFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return '이미 가입된 이메일입니다.';
      case 'weak-password': return '비밀번호는 6자리 이상이어야 합니다.';
      case 'invalid-email': return '유효하지 않은 이메일 형식입니다.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return '이메일 또는 비밀번호가 틀렸습니다.';
      case 'too-many-requests': return '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
      default: return '오류가 발생했습니다: ${e.message}';
    }
  }

  Future<void> _fetchUserProfile() async {
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
      // 1. Firebase Auth 계정 생성
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      final newUser = UserModel(
        uid: uid,
        email: email,
        nickname: nickname,
        isLocationPublic: true, // [cite: 2025-09-15] true 사용
        createdAt: DateTime.now(),
        stats: UserStats(),
      );

      // 2. 닉네임 중복 체크가 포함된 저장 로직 실행
      try {
        await _repo.saveUserWithNicknameCheck(newUser);
      } catch (e) {
        // 닉네임 중복 시 생성된 계정도 삭제 (데이터 꼬임 방지)
        await userCredential.user?.delete();
        rethrow;
      }

      await userCredential.user!.updateDisplayName(nickname);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      // 레포지토리의 "이미 사용 중인 닉네임입니다." 예외 처리
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 비밀번호 재설정 이메일 전송
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
    notifyListeners();
  }
}
