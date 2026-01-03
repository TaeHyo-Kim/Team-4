import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart'; // UserRepository가 있는 경로

class AuthViewModel with ChangeNotifier {
  final UserRepository _userRepo = UserRepository(); // 레포지토리 연결

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 상태 초기화 (화면 전환 시 에러 메시지 삭제용)
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 1. 로그인 기능
  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 파이어베이스 기본 로그인
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password
      );
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      _errorMessage = "로그인 중 알 수 없는 오류가 발생했습니다.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. 회원가입 기능 (트랜잭션 사용)
  Future<void> signUp({
    required String email,
    required String password,
    required String nickname
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Repository의 트랜잭션 함수 호출 (닉네임 중복 체크 + 계정 생성)
      await _userRepo.signUpWithTransaction(
          email: email,
          password: password,
          nickname: nickname
      );
    } catch (e) {
      // Repository에서 던진 에러(예: "이미 존재하는 닉네임입니다")를 그대로 받아서 표시
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. 로그아웃
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  // 에러 메시지 한글 변환기
  String _parseFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return '가입되지 않은 이메일입니다.';
      case 'wrong-password': return '비밀번호가 틀렸습니다.';
      case 'email-already-in-use': return '이미 사용 중인 이메일입니다.';
      case 'invalid-email': return '이메일 형식이 잘못되었습니다.';
      case 'weak-password': return '비밀번호는 6자리 이상이어야 합니다.';
      default: return '오류 발생: ${e.message}';
    }
  }
}