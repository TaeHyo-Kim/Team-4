import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories.dart';
import 'models.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // [추가] FCM 토큰 사용

class AuthViewModel with ChangeNotifier {
  final AuthRepository _repo = AuthRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _userSub;

  // [추가] 중복 로그인 감시를 위한 변수들
  StreamSubscription? _sessionSub;
  String? _currentDeviceToken;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthViewModel() {
    _auth.authStateChanges().listen((firebaseUser) async {
      debugPrint("Auth 상태 변경: ${firebaseUser?.uid}");
      _user = firebaseUser;
      
      _userSub?.cancel();
      _sessionSub?.cancel(); // [추가] 이전 세션 감시 중단

      if (firebaseUser != null) {
        // 1. 현재 기기의 토큰 가져오기
        _currentDeviceToken = await FirebaseMessaging.instance.getToken();
        debugPrint("내 기기 토큰: $_currentDeviceToken"); // 디버깅용

        // 2. [중요] 실시간 세션 감시를 여기서 직접 호출해야 작동함
        _startSessionCheck(firebaseUser.uid);

        _userSub = _repo.userStream(firebaseUser.uid).listen((updatedUser) {
          _userModel = updatedUser;
          notifyListeners();
        }, onError: (e) {
          debugPrint("유저 스트림 에러: $e");
        });
      } else {
        _userModel = null;
        _currentDeviceToken = null;
        notifyListeners();
      }
    });
  }

  // [추가] 실시간 세션 체크 함수
  void _startSessionCheck(String uid) {
    _sessionSub = _db.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final String? lastSessionId = data['lastSessionId'];

        debugPrint("Firestore 세션 ID: $lastSessionId");
        debugPrint("현재 내 기기 토큰: $_currentDeviceToken");

        // Firestore의 세션 ID가 존재하고, 현재 기기의 토큰과 다르다면 중복 로그인 발생
        if (lastSessionId != null && _currentDeviceToken != null &&
            lastSessionId != _currentDeviceToken) {
          debugPrint("세션 불일치 감지! 강제 로그아웃 실행");
          _handleForceLogout();
        }
      }
    });
  }

  // [추가] 강제 로그아웃 처리
  Future<void> _handleForceLogout() async {
    await logout(); // 현재 기기 로그아웃
    _errorMessage = "다른 기기에서 로그인이 감지되어 로그아웃되었습니다.";
    notifyListeners();
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
      case 'user-not-found': return '가입되지 않은 계정입니다.'; // [수정] 분리 및 메시지 변경
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
      // 1. 가입된 계정인지 Firestore에서 먼저 확인 시도
      try {
        final userQuery = await _db.collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          _errorMessage = '가입되지 않은 계정입니다.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        // Firestore 규칙상 비로그인 유저가 접근 불가능할 경우 에러가 날 수 있습니다.
        // 이 경우 확인을 건너뛰고 바로 Auth 로그인을 시도합니다.
        debugPrint("Firestore 가입 여부 확인 실패 (건너뜀): $e");
      }

      // 2. 계정이 존재하거나 확인을 건너뛴 경우 로그인 시도
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      debugPrint("로그인 성공");

      final token = await FirebaseMessaging.instance.getToken();
      _currentDeviceToken = token; // 내 상태 업데이트
      await _db.collection('users').doc(userCredential.user!.uid).update({
        'lastSessionId': token,
      });

    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      debugPrint("로그인 일반 에러: $e");
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
      final token = await FirebaseMessaging.instance.getToken();
      final newUser = UserModel(
        uid: uid,
        email: email,
        nickname: nickname,
        visibility: 'all', // [수정] 모델 필드명 변경 반영
        createdAt: DateTime.now(),
        stats: UserStats(),
      );

      try {
        await _repo.saveUserWithNicknameCheck(newUser);
      } catch (e) {
        await userCredential.user?.delete();
        rethrow;
      }

      // [수정] lastSessionId 필드 포함하여 저장
      final userData = newUser.toMap();
      userData['lastSessionId'] = token;

      await _db.collection('users').doc(uid).set(userData);
      await userCredential.user!.updateDisplayName(nickname);

    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      _errorMessage = e.toString();
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
    _errorMessage = null; // 시작 전 에러 초기화
    notifyListeners();

    try {
      final uid = user.uid;
      await _userSub?.cancel();
      await _sessionSub?.cancel();
      final batch = _db.batch();
      // 1. 계정 삭제 시도 (보안 민감 작업이므로 먼저 수행)
      // 여기서 'requires-recent-login' 에러가 나면 아래 Firestore 삭제를 실행하지 않음
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

      _user = null;
      _userModel = null;
      _currentDeviceToken = null;
      debugPrint("회원 탈퇴 및 세션 정리 완료");

    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseFirebaseError(e);
    } catch (e) {
      debugPrint("탈퇴 일반 에러: $e");
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
