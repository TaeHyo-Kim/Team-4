import 'dart:async';
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
  StreamSubscription? _userSub;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthViewModel() {
    _auth.authStateChanges().listen((firebaseUser) {
      _user = firebaseUser;
      
      // 기존 구독 해제
      _userSub?.cancel();

      if (firebaseUser != null) {
        // [핵심] 유저 데이터 실시간 구독 시작
        _userSub = _repo.userStream(firebaseUser.uid).listen((updatedUser) {
          _userModel = updatedUser;
          notifyListeners(); // 서버 데이터가 변경될 때마다 앱 UI를 즉시 갱신
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

  // [중요] 영문 에러 코드를 한국어 메시지로 변환
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

  // 비밀번호 재설정 이메일 전송 기능 추가
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

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
