import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart'; // 통합 리포지토리 import
import '../auth/models.dart';         // 유저 모델 import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:typed_data'; // [해결] Undefined class 'ByteData' 에러 해결

class SocialViewModel with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SocialRepository _repo = SocialRepository();
  final _geo = GeoFlutterFire();

  Timer? _locationUpdateTimer;
  Timer? _nearbyRefreshTimer;

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  Set<String> _followingIds = {};
  Set<String> _blockedIds = {};
  List<UserModel> _blockedUserList = [];
  List<UserModel> _nearbyUsers = []; // 주변 사용자 목록

  // 현재 검색어 상태 저장 (팔로우 토글 시 리스트 유지를 위함)
  String _currentSearchQuery = '';
  bool _isLoading = false;

  List<UserModel> get users => _filteredUsers;
  List<UserModel> get blockedUserList => _blockedUserList;
  bool get isLoading => _isLoading;
  List<UserModel> get nearbyUsers => _nearbyUsers;

  SocialViewModel() {
    fetchUsers();
  }

  BitmapDescriptor? _myLocationIcon;
  BitmapDescriptor? get myLocationIcon => _myLocationIcon;

  BitmapDescriptor? _myProfileIcon;
  BitmapDescriptor? get myProfileIcon => _myProfileIcon; // views.dart에서 접근할 이름

  //  주변 사용자들의 마커 아이콘을 저장할 Map (Key: uid, Value: 마커)
  Map<String, BitmapDescriptor> _nearbyMarkers = {};
  Map<String, BitmapDescriptor> get nearbyMarkers => _nearbyMarkers;

  // URL을 원형 마커로 변환하는 공통 로직 (기존 createProfileMarker 로직 활용)
  Future<BitmapDescriptor?> _generateCircularMarker(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final http.Response response = await http.get(Uri.parse(imageUrl));
      final ui.Codec codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: 120,
        targetHeight: 120,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..isAntiAlias = true;
      const double radius = 60.0;

      canvas.drawCircle(const Offset(radius, radius), radius, paint);
      paint.blendMode = BlendMode.srcIn;
      canvas.drawImage(image, Offset.zero, paint);

      final Paint borderPaint = Paint()
        ..color = const Color(0xFFFF9800) // 주황색 테두리
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawCircle(const Offset(radius, radius), radius, borderPaint);

      final ui.Image finalImage = await pictureRecorder.endRecording().toImage(120, 120);
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    } catch (e) {
      debugPrint("마커 생성 실패: $e");
      return null;
    }
  }

  String? _currentMarkerUrl; // 현재 마커로 생성된 이미지의 URL 저장용
  String? get currentMarkerUrl => _currentMarkerUrl; // 뷰에서 비교하기 위한 getter

  // 프로필 이미지를 원형 마커로 변환 (산책 기능 로직 재사용)
  Future<void> createProfileMarker(String? imageUrl) async {
    if (imageUrl == _currentMarkerUrl && _myProfileIcon != null) return;

    _currentMarkerUrl = imageUrl;

    // 2. 이미지가 없는 경우 기본 마커 생성
    if (imageUrl == null || imageUrl.isEmpty) {
      _myProfileIcon = await _generateDefaultCircularMarker();
      notifyListeners();
      return;
    }

    // 3. 이미지가 있는 경우 원형 마커 생성
    try {
      final marker = await _generateCircularMarker(imageUrl);
      if (marker != null) {
        _myProfileIcon = marker;
      } else {
        // 다운로드 실패 시 기본 마커로 대체
        _myProfileIcon = await _generateDefaultCircularMarker();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("마커 갱신 오류: $e");
      _myProfileIcon = await _generateDefaultCircularMarker();
      notifyListeners();
    }
  }

  // [추가] 프로필 사진이 없는 사용자를 위한 기본 원형 마커 생성
  Future<BitmapDescriptor> _generateDefaultCircularMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.grey[300]!..isAntiAlias = true;
    const double radius = 60.0;

    // 배경 원형 (회색)
    canvas.drawCircle(const Offset(radius, radius), radius, paint);

    // 테두리 (주황색)
    final Paint borderPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(const Offset(radius, radius), radius, borderPaint);

    // [선택] 사람 아이콘이나 텍스트를 추가로 그려넣을 수 있습니다.

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(120, 120);
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // [추가] 내 프로필 이미지를 마커용 비트맵으로 변환
  Future<void> createMyLocationMarker(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      _myLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      notifyListeners();
      return;
    }

    try {
      final http.Response response = await http.get(Uri.parse(imageUrl));
      final ui.Codec codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: 120, // 마커 사이즈 조절
        targetHeight: 120,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..isAntiAlias = true;
      const double radius = 60.0;

      // 원형 클리핑
      canvas.drawCircle(const Offset(radius, radius), radius, paint);
      paint.blendMode = BlendMode.srcIn;
      canvas.drawImage(image, Offset.zero, paint);

      // 테두리 추가 (선택 사항)
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawCircle(const Offset(radius, radius), radius, borderPaint);

      final ui.Image finalImage = await pictureRecorder.endRecording().toImage(120, 120);
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      _myLocationIcon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
      notifyListeners();
    } catch (e) {
      debugPrint("마커 생성 실패: $e");
      _myLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      notifyListeners();
    }
  }

  // fetchUsers 등 초기화 시 호출하도록 보강
  Future<void> initSocialData(UserModel? myProfile) async {
    if (myProfile != null) {
      await createMyLocationMarker(myProfile.profileImageUrl);
    }
    await fetchUsers();
  }

  // [추가] 30초 주기 위치 업데이트 시작
  void startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await updateMyPosition();
    });
  }

  // [수정] 주변 사용자 10초 주기 자동 갱신 시작
  void startNearbyRefresh() {
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // 검색창에 입력이 없을 때만 주변 유저 정보를 갱신하여 UX 방해 방지
      if (_currentSearchQuery.isEmpty) {
        await fetchNearbyUsers();
      }
    });
  }

  // [수정] 페이지 이탈 시 모든 타이머 정지
  void stopAllSocialTimers() {
    _locationUpdateTimer?.cancel();
    _nearbyRefreshTimer?.cancel();
  }

// [추가] 내 위치를 Firestore users/position 필드에 갱신
  Future<void> updateMyPosition() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      // Firestore 업데이트
      await _db.collection('users').doc(myUid).update({
        'position': GeoPoint(position.latitude, position.longitude),
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      // 내 위치 갱신 후 주변 사용자 다시 불러오기
      await fetchNearbyUsers();
    } catch (e) {
      debugPrint("내 위치 갱신 실패: $e");
    }
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel(); // 타이머 해제 필수
    super.dispose();
  }

  Future<void> toggleLike({
    required String walkId,
    required String ownerId,
    required String myNickname,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final walkRef = FirebaseFirestore.instance.collection('walks').doc(walkId);
    final likeRef = walkRef.collection('likes').doc(myUid);
    final notificationRef = FirebaseFirestore.instance.collection('notifications');

    // 1. 현재 좋아요 상태 확인
    final likeDoc = await likeRef.get();
    final isAdding = !likeDoc.exists;

    try {
      if (isAdding) {
        // 좋아요 추가
        await likeRef.set({
          'nickname': myNickname,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // walk 문서의 likeCount 업데이트 (이미지 구조에 맞춰서)
        await walkRef.update({'likeCount': FieldValue.increment(1)});

        // 알림 추가 (이미지_281956.png 구조 참고)
        await notificationRef.add({
          'body': "회원님의 산책 기록을 좋아합니다.",
          'createdAt': FieldValue.serverTimestamp(),
          'fromUserId': myUid,
          'fromUserNickname': myNickname,
          'postId': walkId,
          'read': false,
          'title': "$myNickname님이 내 기록을 좋아합니다.",
          'type': "like",
          'userId': ownerId, // 게시물 주인 ID
        });
      } else {
        // 좋아요 취소
        await likeRef.delete();
        await walkRef.update({'likeCount': FieldValue.increment(-1)});

        // (옵션) 좋아요 취소 시 기존 알림을 삭제하고 싶다면 추가 로직 필요
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Like Toggle Error: $e");
      rethrow;
    }
  }

  // 주변 사용자 불러오기 (반경 1km)
  Future<void> fetchNearbyUsers() async {
    try {
      Position myPos = await Geolocator.getCurrentPosition();

      _nearbyUsers = _allUsers.where((user) {
        if (user.uid == _auth.currentUser?.uid) return false;
        if (user.position == null) return false;

        // [해결] GeoPoint.latitude에 직접 접근
        double distance = Geolocator.distanceBetween(
          myPos.latitude, myPos.longitude,
          user.position!.latitude, user.position!.longitude,
        );
        return distance <= 1000; // 1km 이내
      }).toList();

      //  새로 발견된 주변 사용자의 프로필 마커 생성
      for (var user in _nearbyUsers) {
        if (!_nearbyMarkers.containsKey(user.uid)) {
          if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
            final markerIcon = await _generateCircularMarker(user.profileImageUrl);
            _nearbyMarkers[user.uid] = markerIcon ?? await _generateDefaultCircularMarker();
          } else {
            // 사진 없는 유저 처리
            _nearbyMarkers[user.uid] = await _generateDefaultCircularMarker();
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Nearby Users Error: $e");
    }
  }

  Future<void> fetchUsers() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _allUsers = await _repo.getAllUsers(myUid);
      _followingIds = await _repo.getMyFollowingIds(myUid);
      _blockedIds = await _repo.getBlockedUserIds(myUid);

      // 2. 필터링 및 주변 유저 계산 실행
      _applyFilter();
      await fetchNearbyUsers();
    } catch (e) {
      debugPrint("Social Data Load Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 차단된 유저 상세 목록 불러오기 (설정 화면용)
  Future<void> fetchBlockedUsers() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      _blockedUserList = await _repo.getBlockedUsers(myUid);
    } catch (e) {
      debugPrint("Fetch Blocked Users Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // [수정] 검색 및 팔로우 목록 필터링
  void _applyFilter() {
    // 차단되지 않은 유저 중 나를 제외한 전체 유저
    var baseUsers = _allUsers.where((u) => !_blockedIds.contains(u.uid));

    if (_currentSearchQuery.isEmpty) {
      // 검색어가 없을 때: 내가 팔로우한 사람들만 표시
      _filteredUsers = baseUsers.where((user) => _followingIds.contains(user.uid)).toList();
    } else {
      // 검색어가 있을 때: 닉네임 검색 결과 표시
      _filteredUsers = baseUsers.where((user) =>
          user.nickname.toLowerCase().contains(_currentSearchQuery.toLowerCase())).toList();
    }
    notifyListeners();
  }

  void searchUsers(String query) {
    _currentSearchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  Future<void> toggleFollow(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final isFollowing = _followingIds.contains(targetUid);

    if (isFollowing) {
      _followingIds.remove(targetUid);
    } else {
      _followingIds.add(targetUid);
    }

    _applyFilter();
    notifyListeners();

    try {
      if (isFollowing) {
        await _repo.unfollowUser(myUid: myUid, targetUid: targetUid);
      } else {
        await _repo.followUser(myUid: myUid, targetUid: targetUid);
      }
    } catch (e) {
      if (isFollowing) {
        _followingIds.add(targetUid);
      } else {
        _followingIds.remove(targetUid);
      }
      _applyFilter();
      notifyListeners();
      rethrow;
    }
  }

  // 차단 실행/해제 (프로필에서 호출)
  Future<void> toggleBlock(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    if (_blockedIds.contains(targetUid)) {
      await unblockUser(targetUid);
    } else {
      await _repo.blockUser(myUid: myUid, targetUid: targetUid);
      _blockedIds.add(targetUid);
      _followingIds.remove(targetUid); // 차단 시 팔로우 해제 반영
      _applyFilter();
      notifyListeners();
    }
  }

  // 차단 해제 전용 (설정 화면 등에서 사용)
  Future<void> unblockUser(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      await _repo.unblockUser(myUid: myUid, targetUid: targetUid);
      _blockedIds.remove(targetUid);
      _blockedUserList.removeWhere((u) => u.uid == targetUid);
      _applyFilter();
      notifyListeners();
    } catch (e) {
      debugPrint("Unblock Error: $e");
    }
  }

  bool isFollowing(String uid) => _followingIds.contains(uid);
  bool isBlocked(String uid) => _blockedIds.contains(uid);

  // [추가] 좋아요 누른 사람들 목록 가져오기 UI 반영
  Future<List<Map<String, dynamic>>> getLikers(String walkId) async {
    final snapshot = await _db.collection('walks').doc(walkId).collection('likes').get();
    List<Map<String, dynamic>> likers = [];

    for (var doc in snapshot.docs) {
      final userDoc = await _db.collection('users').doc(doc.id).get();
      if (userDoc.exists) {
        likers.add({
          'uid': doc.id,
          'nickname': userDoc.data()?['nickname'] ?? '익명',
          'profileImageUrl': userDoc.data()?['profileImageUrl'] ?? '',
          'email': userDoc.data()?['email'] ?? '',
        });
      }
    }
    return likers;
  }
}