import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart';
import 'models.dart';

class AuthViewModel with ChangeNotifier {
  // 통합된 Repository 사용
  final AuthRepository _repo = AuthRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  User? get user => _user;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

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

  // [수정됨] 리포지토리의 표준 메소드(getUser) 사용
  Future<void> _fetchUserProfile() async {
    if (_user == null) return;

    try {
      // 내 UID로 정보를 가져옴
      _userModel = await _repo.getUser(_user!.uid);
      notifyListeners();
    } catch (e) {
      print("프로필 로드 실패: $e");
    }
  }

  // 로그인
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // 로그인 성공 시 리스너가 _fetchUserProfile 자동 실행
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // [수정됨] 회원가입 로직 변경
  // (ViewModel에서 Auth 계정 생성 -> Repository에 유저 정보 저장)
  Future<void> signUp(String email, String password, String nickname) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Firebase Auth에 계정 생성
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception("회원가입 실패: 유저 정보가 없습니다.");
      }

      final uid = userCredential.user!.uid;

      // 2. 저장할 유저 모델 생성
      final newUser = UserModel(
        uid: uid,
        email: email,
        nickname: nickname,
        profileImageUrl: null, // 초기값 null
        createdAt: DateTime.now(),
        stats: UserStats(),     // 초기 통계 0
      );

      // 3. Firestore에 저장 (리포지토리 호출)
      await _repo.saveUser(newUser);

      // 4. (선택) 닉네임 등을 Firebase Auth 프로필에도 업데이트하면 좋음
      await userCredential.user!.updateDisplayName(nickname);

      // 회원가입 성공 시, AuthStateChanges가 감지하여 로그인 처리됨
    } catch (e) {
      // 실패하면 생성된 계정도 지워주는 롤백 로직이 있으면 좋지만,
      // 일단은 에러를 던짐
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 로그아웃
  Future<void> logout() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }
}