import 'dart:async';
import 'dart:convert'; // encodedPath 변환용 (JSON)
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp, GeoPoint용
import '../../data/database_helper.dart';
import '../../data/repositories.dart';
import 'models.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class WalkViewModel with ChangeNotifier {
  final WalkRepository _repo = WalkRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // [수정 10] 이모지 그룹화
  final List<List<String>> emojiGroups = [
    ['👍', '👌', '❤️', '😊', '🥰'], // 그룹 1 (기본 노출)
    ['🐕', '🐈', '🐶', '🐾', '🦴'], // 그룹 2
    ['🏃', '🌳', '☀️', '✨', '🌟'], // 그룹 3
    ['💧', '👎', '😎', '🤗', '🎉'], // 그룹 4
  ];
  List<String> currentEmojiRow = ['👍', '👌', '❤️', '😊', '🥰'];

  // ------------------------------------------------------------------------
  // 상태 변수들
  // ------------------------------------------------------------------------
  Set<Marker> snapshotMarkers = {}; // 캡처 전용 마커 셋
  // 카메라 제어용
  GoogleMapController? _mapController;
  Timer? _inactivityTimer;
  bool _isUserInteracting = false;

  bool _isWalking = false;
  bool _isPaused = false;
  int _seconds = 0;
  double _distance = 0.0; // 미터 단위 (모델 저장 시 km로 변환)

  List<LatLng> _route = []; // 지도 표시용 경로
  LatLng? _currentPosition; // 현재 위치
  LatLng? _startPosition; // 시작 위치 (모델의 startLocation용)
  DateTime? _startTime; // 시작 시간 (모델용)

  List<String> _selectedPetIds = [];
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;

  int walkState = 0; // 0: 홈, 1: 산책 중, 2: 요약(5번), 3: 후기 작성(6번)
  List<Map<String, dynamic>> myPets = []; // {id, name, isPrimary, ...} 형태
  Map<String, dynamic>? selectedPet; // 단일 선택 (기존 호환성 유지)
  Map<String, dynamic>? recentWalk;
  Set<String> selectedPetIds = {}; // 여러 반려동물 선택용
  StreamSubscription<
      QuerySnapshot>? _recentWalkSubscription; // 최근 산책 기록 실시간 스트림
  StreamSubscription<QuerySnapshot>? _petsSubscription; // 반려동물 목록 실시간 스트림

  // 후기 작성 관련 필드
  List<XFile> reviewImages = [];
  int currentImageIndex = 0;
  String selectedEmoji = '👍'; // 기본 이모지
  final TextEditingController reviewController = TextEditingController();
  DateTime? endTime; // 요약 화면 표기용

  // 배율 변경: 1:12,500은 줌 레벨 약 16.5 ~ 17.0
  final double _defaultZoom = 16.5;

  // ------------------------------------------------------------------------
  // Getters
  // ------------------------------------------------------------------------
  bool get isWalking => _isWalking;

  bool get isPaused => _isPaused;

  int get seconds => _seconds;

  double get distance => _distance;

  List<LatLng> get route => _route;

  LatLng? get currentPosition => _currentPosition;

  bool get isUserInteracting => _isUserInteracting;

  DateTime? get startTime => _startTime;

  int get totalDots => reviewImages.isEmpty ? 1 : reviewImages.length;

  // [추가] 산책 강제 취소 및 상태 초기화
  void cancelWalk() {
    // 위치 추적 중단
    _positionStream?.cancel();
    _timer?.cancel();

    // 상태 변수 초기화
    _isWalking = false;
    _isPaused = false;
    _seconds = 0;
    _distance = 0.0;
    _route = [];
    _currentPosition = null;
    _startPosition = null;

    // UI 상태를 홈(0)으로 복구
    walkState = 0;

    // 입력 필드 초기화
    reviewImages.clear();
    reviewController.clear();

    notifyListeners();

    // 카메라를 다시 현재 위치로 잡기 위해 호출
    fetchCurrentLocation();
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      moveToCurrentLocation();
    }
  }

  // 사용자가 지도를 터치했을 때 호출
  void onUserInteractionStarted() {
    _isUserInteracting = true;
    _inactivityTimer?.cancel();
    notifyListeners();
  }

  // 사용자가 터치를 뗐을 때 호출 (10초 카운트다운 시작)
  void onUserInteractionEnded() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 5), () {
      _isUserInteracting = false;
      moveToCurrentLocation();
      notifyListeners();
    });
  }

  // 현재 위치로 카메라 이동
  // 1. 카메라 이동 함수에 try-catch와 mounted 체크(유사 로직) 추가
  Future<void> moveToCurrentLocation() async {
    // 컨트롤러가 없거나 지도가 해제되었다면 실행하지 않음
    if (_currentPosition == null || _mapController == null) return;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: _defaultZoom,
          ),
        ),
      );
    } catch (e) {
      // 지도가 이미 dispose 되었을 때 발생하는 에러를 여기서 잡아줌
      debugPrint("카메라 이동 중 에러 발생 (무시 가능): $e");
    }
  }

  void selectEmojiGroup(int groupIndex) {
    currentEmojiRow = emojiGroups[groupIndex];
    selectedEmoji = currentEmojiRow[0];
    notifyListeners();
  }

  // 화면 진입 시 초기 위치 로드
  Future<void> fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = LatLng(position.latitude, position.longitude);
      moveToCurrentLocation();
      notifyListeners();
    } catch (e) {
      debugPrint("위치 가져오기 실패: $e");
    }
  }

  // ------------------------------------------------------------------------
  // 1. 산책 시작
  // ------------------------------------------------------------------------
  Future<void> startWalk(List<String> petIds) async {
    if (_isWalking) return;
    bool hasPermission = await _checkPermission();
    if (!hasPermission) throw Exception("위치 권한이 필요합니다.");

    // 초기화
    _isWalking = true;
    _isPaused = false;
    _seconds = 0;
    _distance = 0.0;
    _route = [];
    _selectedPetIds = petIds;
    _startTime = DateTime.now(); // 시작 시간 기록

    // 현재 위치를 시작 위치로 고정 (null일 경우 대비 로직 포함)
    if (_currentPosition != null) {
      _startPosition = _currentPosition;
    } else {
      // 만약 아직 위치를 못 잡았다면 즉시 가져오기 시도
      Position p = await Geolocator.getCurrentPosition();
      _startPosition = LatLng(p.latitude, p.longitude);
      _currentPosition = _startPosition;
    }

    _startTimer();
    _startLocationTracking();
    moveToCurrentLocation(); // 시작 시 중심 맞춤

    // 산책 중 상태(1)로 변경
    walkState = 1;
    notifyListeners();
  }


  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) async {
          if (!_isWalking || walkState != 1) return;

          final newPoint = LatLng(position.latitude, position.longitude);
          // [추가] 로컬 DB에 즉시 저장
          await WalkDbHelper.instance.insertPoint(
              newPoint.latitude, newPoint.longitude);

          if (_route.isNotEmpty) {
            final lastPoint = _route.last;
            final dist = Geolocator.distanceBetween(
              lastPoint.latitude, lastPoint.longitude,
              newPoint.latitude, newPoint.longitude,
            );
            if (dist < 300) {
              _distance += dist;
              _route.add(newPoint);
            }
          } else {
            _startPosition ??= newPoint;
            _route.add(newPoint);
          }

          _currentPosition = newPoint;

          // 사용자가 조작 중이 아닐 때만 카메라 자동 추적
          if (!_isUserInteracting) moveToCurrentLocation();
          notifyListeners();
        });
  }

  // 2. 일시정지 / 재개 - 삭제

  // ------------------------------------------------------------------------
  // 3. 산책 종료 및 저장 (모델 구조에 맞춤)
  // ------------------------------------------------------------------------
  // memo, emoji, visibility는 종료 화면에서 입력받아 전달한다고 가정
  Future<void> stopWalk({
    String memo = '',
    String emoji = '🐕',
    String visibility = 'public',
    List<String> photoUrls = const [],
  }) async {
    // [수정] walkState 3(후기 작성 상태)에서도 저장이 가능하도록 조건 변경
    if (!_isWalking && walkState != 2 && walkState != 3) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // 스트림 종료
    _positionStream?.cancel();
    _timer?.cancel();
    _isWalking = false;
    _isPaused = false;

    // 1. 데이터 가공
    final walkEndTime = endTime ?? DateTime.now();
    final double distanceKm = _distance / 1000.0; // 미터 -> km 변환
    final double calories = _calculateCalories(_distance); // 칼로리 계산

    // 경로 인코딩 (간단히 JSON String으로 변환)
    // 실제 Polyline Encoding 알고리즘을 쓰려면 flutter_polyline_points 패키지 필요
    final String encodedPathStr = jsonEncode(
        _route.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList()
    );

    // 시작 위치 GeoPoint 변환
    final startGeoPoint = _startPosition != null
        ? GeoPoint(_startPosition!.latitude, _startPosition!.longitude)
        : const GeoPoint(0, 0);

    // 2. 모델 생성
    final newRecord = WalkRecordModel(
      id: null,
      // Firestore 자동 ID
      userId: userId,
      petIds: _selectedPetIds,
      startTime: Timestamp.fromDate(_startTime ?? DateTime.now()),
      endTime: Timestamp.fromDate(walkEndTime),
      duration: _seconds,
      distance: distanceKm,
      calories: calories,
      encodedPath: encodedPathStr,
      startLocation: startGeoPoint,
      startGeohash: '',
      // GeoHash 라이브러리가 없으면 빈값 (필요 시 geoflutterfire 추가)
      memo: memo,
      emoji: emoji,
      visibility: visibility,
      photoUrls: photoUrls,
      likeCount: 0,
    );

    // [보정 로직 4] 네트워크 미연결 시 재시도 로직이 포함된 저장
    try {
      // 1. 서버 업로드 시도
      await _repo.saveWalk(newRecord);
      // 2. 서버 저장 성공 시 로컬 캐시 삭제
      await WalkDbHelper.instance.clearCache();
    } catch (e) {
      // 실패 시 로컬 DB에 데이터가 남아있으므로, 나중에 재시도 로직 구현 가능
      debugPrint("업로드 실패, 로컬 DB에 좌표 보존됨: $e");
      rethrow;
    } finally {
      _positionStream?.cancel();
      _timer?.cancel();
      _isWalking = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------------
  // Helper: 칼로리 계산 (성인 70kg 기준 표준 공식 적용)
  // ------------------------------------------------------------------------
  double _calculateCalories(double distanceMeters) {
    // 성인(약 70kg) 기준 걷기 운동은 1km당 약 70~72kcal를 소모합니다.
    // 미터당 약 0.072kcal로 계산하여 보다 정확한 수치를 제공합니다.
    return distanceMeters * 0.072;
  }

  // ------------------------------------------------------------------------
  // 내부 로직
  // ------------------------------------------------------------------------
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _seconds++;
        notifyListeners();
      }
    });
  }

  // 보정 로직을 위한 설정값
  final double _accuracyThreshold = 20.0; // 20m 이상 오차 무시

  // [추가 6] 스와이프 제어를 위한 컨트롤러
  final PageController pageController = PageController();

  // [수정 5] 다중 이미지 선택으로 변경
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // pickImage -> pickMultiImage로 변경
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      reviewImages.addAll(images);
      currentImageIndex = reviewImages.length - 1;
      notifyListeners();

      // 새 사진 추가 후 해당 페이지로 이동
      Future.delayed(const Duration(milliseconds: 100), () {
        pageController.jumpToPage(currentImageIndex);
      });
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < reviewImages.length) {
      reviewImages.removeAt(index);
      if (currentImageIndex >= reviewImages.length && currentImageIndex > 0) {
        currentImageIndex--;
      } else if (reviewImages.isEmpty) {
        currentImageIndex = 0;
      }
      notifyListeners();
    }
  }

// [수정] 산책 종료 버튼 클릭 시 실행될 핵심 로직
  Future<void> completeWalk() async {
    if (!_isWalking) return;

    try {
      // [중요] 기존에 돌아가고 있던 '5초 대기 타이머'를 즉시 제거
      _inactivityTimer?.cancel();
      _inactivityTimer = null;

      // 1. 상태 즉시 변경 (시간/거리 갱신 중단)
      _isWalking = false;
      endTime = DateTime.now(); // [해결] 종료 시점의 시간을 기록하여 --:-- 표기 방지

      // 타이머 및 위치 스트림 종료
      _timer?.cancel();
      _timer = null;
      _positionStream?.cancel();
      _positionStream = null;

      notifyListeners(); // 요약 화면으로 넘어가기 전 상태 업데이트

      // 2. 스냅샷 촬영 (전체 경로가 보이도록 카메라 조정 후 캡처)
      await _captureFullRouteSnapshot();

      // 3. 화면 상태 전환 (요약 화면(2)으로 이동)
      walkState = 2;
      notifyListeners();
    } catch (e) {
      debugPrint("산책 종료 중 오류 발생: $e");
      // 종료 프로세스 자체에 에러가 나도 요약 화면으로 일단 보내거나 에러 알림
      walkState = 2;
      notifyListeners();
    }
  }

  // [수정 1] 산책 종료 시 전체 경로 캡처 로직
  Future<void> finishWalkWithSnapshot() async {
    if (_route.isEmpty || _mapController == null) {
      finishWalk();
      return;
    }

    // 1. 전체 경로가 다 보이도록 좌표 경계 계산
    LatLngBounds bounds = _getBounds(_route);

    // 2. 지도 배율 조정 (Padding 50 주어 여유 있게 보정)
    await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50));

    // 3. 지도가 렌더링될 때까지 잠시 대기 후 캡처
    await Future.delayed(const Duration(milliseconds: 500));
    final Uint8List? imageBytes = await _mapController!.takeSnapshot();

    if (imageBytes != null) {
      // 4. 바이트 데이터를 임시 파일로 저장하여 이미지 리스트 첫 번째에 추가
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/walk_snap_${DateTime
          .now()
          .millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(imageBytes);

      reviewImages.insert(0, XFile(file.path)); // 첫 번째 사진으로 삽입
    }

    finishWalk(); // 기존 종료 로직 호출 (상태 2로 변경 등)
  }

  // [수정 1] 스냅샷 캡처 (시작점: 빨강, 도착점: 파랑)
  Future<void> captureSnapshot() async {
    if (_route.isEmpty || _mapController == null) return;

    // 1. 시작점과 끝점 마커 설정 (기존 펫 마커 제외)
    snapshotMarkers = {
      Marker(
        markerId: const MarkerId("start"),
        position: _route.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      Marker(
        markerId: const MarkerId("end"),
        position: _route.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
    notifyListeners();

    // 2. 경로가 모두 보이도록 카메라 조정
    LatLngBounds bounds = _getBounds(_route);
    await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50));

    // 3. 렌더링 대기 후 캡처
    await Future.delayed(const Duration(milliseconds: 600));
    final Uint8List? imageBytes = await _mapController!.takeSnapshot();

    if (imageBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/walk_${DateTime
          .now()
          .millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(imageBytes);
      reviewImages.insert(0, XFile(file.path));
    }

    // 캡처 후 상태 업데이트
    snapshotMarkers.clear();
    notifyListeners();
  }

  // [추가] 경로 전체 스냅샷 캡처 로직
  Future<void> _captureFullRouteSnapshot() async {
    // 지도가 없거나 경로가 없으면 즉시 리턴
    if (_route.isEmpty || _mapController == null) return;

    try {
      // 1) 전체 경로를 포함하는 경계(Bounds) 계산
      LatLngBounds bounds = _getBounds(_route);

      // 2) 모든 경로가 보이도록 카메라 이동 (여백 50)
      await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50));

      // 3) 지도가 완전히 렌더링될 때까지 충분히 대기 (중요)
      await Future.delayed(const Duration(milliseconds: 800));

      // 여기서 "Bad state" 에러가 날 확률이 높으므로 다시 한 번 체크
      if (_mapController != null) {
        // 4) 스냅샷 촬영
        final Uint8List? imageBytes = await _mapController!.takeSnapshot();

        if (imageBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final file = await File('${tempDir.path}/walk_snap_${DateTime
              .now()
              .millisecondsSinceEpoch}.png').create();
          await file.writeAsBytes(imageBytes);

          // 5) 후기 이미지 리스트의 '첫 번째' 인덱스에 삽입
          reviewImages.insert(0, XFile(file.path));
          debugPrint("전체 경로 스냅샷이 reviewImages[0]에 저장되었습니다.");
        }
      }
    } catch (e) {
      debugPrint("스냅샷 캡처 중 오류 발생: $e");
    }
  }

  // [수정 3] 이모지 선택 시 행 교체 로직 (첫 번째가 아닌 선택한 것이 강조됨)
  void selectEmojiFromPopup(int groupIndex, String emoji) {
    currentEmojiRow = emojiGroups[groupIndex];
    selectedEmoji = emoji; // 내가 선택한 이모지를 유지
    notifyListeners();
  }

  // 좌표 리스트로부터 Bounds 계산 유틸리티
  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // [추가] 페이지 변경 시 인덱스 동기화
  void onPageChanged(int index) {
    currentImageIndex = index;
    notifyListeners();
  }

  // [수정] 화살표 클릭 시 PageView 이동
  void movePage(int direction) {
    int nextIndex = currentImageIndex + direction;
    if (nextIndex >= 0 && nextIndex < reviewImages.length) {
      pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }


  void setCurrentImageIndex(int index) {
    if (index >= 0 && index < reviewImages.length) {
      currentImageIndex = index;
      notifyListeners();
    }
  }

  void setCurrentImageIndexIncrement() {
    if (currentImageIndex < reviewImages.length - 1) {
      currentImageIndex++;
      notifyListeners();
    }
  }

  void setCurrentImageIndexDecrement() {
    if (currentImageIndex > 0) {
      currentImageIndex--;
      notifyListeners();
    }
  }

  void setSelectedEmoji(String emoji) {
    selectedEmoji = emoji;
    notifyListeners();
  }

  // [수정 및 추가] 펫 이미지를 2배 크기 원형 마커로 변환하는 함수
  Future<BitmapDescriptor> getPetMarkerIcon(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      // 이미지가 없을 경우 주황색 기본 마커 반환
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }

    try {
      // 1. 이미지 다운로드
      final http.Response response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception("이미지 로드 실패");

      final Uint8List imageBytes = response.bodyBytes;

      // 2. 이미지 가공 (원형 절삭 및 리사이징)
      // targetWidth/Height를 150~200 정도로 설정하여 2배 크기 효과를 줌
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 160,
        targetHeight: 160,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()
        ..isAntiAlias = true;
      final double radius = 80.0; // 반지름 (가로세로 160의 절반)

      // 원형 클리핑 및 이미지 그리기
      canvas.drawCircle(Offset(radius, radius), radius, paint);
      paint.blendMode = BlendMode.srcIn;
      canvas.drawImage(image, Offset.zero, paint);

      // 3. 최종 비트맵 변환
      final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
          160, 160);
      final ByteData? byteData = await finalImage.toByteData(
          format: ui.ImageByteFormat.png);
      final Uint8List finalBytes = byteData!.buffer.asUint8List();

      return BitmapDescriptor.fromBytes(finalBytes);
    } catch (e) {
      debugPrint("마커 생성 에러: $e");
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  // [수정] 산책 종료 시 시간 기록 및 상태 변경
  void finishWalk() {
    endTime = DateTime.now();
    _isWalking = false; // 산책 버튼 잠김 해제의 핵심
    _timer?.cancel();
    _timer = null; // 재확인 방지
    _positionStream?.cancel();
    _positionStream = null;
    walkState = 2; // 요약 화면으로 이동
    notifyListeners();
  }

  bool _isSaving = false; // 중복 저장 방지 플래그
  // [추가] 외부에서 접근 가능한 Getter 정의
  bool get isSaving => _isSaving;

  // 산책 종료 및 저장 (후기 포함)
  Future<void> stopWalkAndSave(String memo) async {
    // 1. 중복 클릭 방지 (로그의 StorageTask 성공 후 취소 에러 관련)
    if (_isSaving) return;

    try {
      _isSaving = true; // 저장 시작
      notifyListeners();

      // [보강 2] 사용자 체크: 로그인이 안 되어 있으면 에러를 던져야 함
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception("로그인 정보가 없습니다. 다시 로그인 해주세요.");
      }

      // 이미지 업로드
      // 1. 이미지 업로드 (로그상 이 부분은 현재 성공 중)
      List<String> photoUrls = [];
      for (final imageFile in reviewImages) {
        final ref = FirebaseStorage.instance.ref().child('walks/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');

        // 업로드 실행 및 완료 대기
        final uploadTask = await ref.putFile(File(imageFile.path));
        if (uploadTask.state == TaskState.success) {
          final url = await ref.getDownloadURL();
          photoUrls.add(url);
        }
      }

      // 2. ★ Firestore 저장 (이 부분이 실패할 확률이 높음)
      // stopWalk 함수 내부에 반드시 await _repo.saveWalk(...)가 있어야 합니다.
      await stopWalk(
        memo: memo,
        emoji: selectedEmoji,
        visibility: 'public',
        photoUrls: photoUrls,
      );

      // 3. 모든 작업 완료 후 초기화
      walkState = 0;
      reviewImages.clear();
      reviewController.clear();

    } catch (e) {
      debugPrint("최종 단계 실패 에러 내용: $e");
      rethrow; // View의 try-catch로 에러 전달
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _saveToLocalCache(List<LatLng> points) {
    // SharedPreferences나 sqflite에 현재 경로를 임시 저장하는 로직을 여기에 구현합니다.
    // 이는 네트워크 단절 후 앱이 강제 종료되었을 때 데이터를 보호합니다.
  }


  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _positionStream?.cancel();
    _timer?.cancel();
    _recentWalkSubscription?.cancel();
    _petsSubscription?.cancel();
    reviewController.dispose();
    _mapController = null; // 컨트롤러 참조 해제
    super.dispose();
  }

  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    return permission != LocationPermission.deniedForever;
  }

  // [추가] 초기 데이터 로드 통합 함수
  Future<void> initWalkScreen() async {
    await checkLocationPermission();
    await fetchCurrentLocation();

    // 반려동물 목록 실시간 스트림 설정
    setupPetsStream();

    // 최근 산책 기록 실시간 스트림 설정
    setupRecentWalkStream();

    // 위치 추적은 산책이 시작될 때만 시작하도록 변경
    // (initWalkScreen에서는 위치 추적을 시작하지 않음)
  }

  // [수정] 진입 시 위치 권한 체크 (항상 허용이 아닐 경우 팝업)
  Future<void> checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      await Geolocator.requestPermission();
    }
  }

  // 내 반려동물 목록 가져오기 (isPrimary 기준 정렬) - 단발성
  Future<void> fetchMyPets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('ownerId', isEqualTo: uid)
          .get();

      // 문서 ID도 함께 저장
      myPets = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // 문서 ID 추가
        return data;
      }).toList();

      _updatePetsList();
    } catch (e) {
      debugPrint("반려동물 목록 로드 실패: $e");
    }
  }

  // 반려동물 목록 업데이트 및 정렬
  void _updatePetsList() {
    // isPrimary가 true인 동물을 우선 정렬
    myPets.sort((a, b) {
      final aPrimary = a['isPrimary'] == true ? 1 : 0;
      final bPrimary = b['isPrimary'] == true ? 1 : 0;
      return bPrimary.compareTo(aPrimary);
    });

    if (myPets.isNotEmpty) {
      // 대표 반려동물을 기본값으로 설정
      selectedPet = myPets.firstWhere((p) => p['isPrimary'] == true,
          orElse: () => myPets.first);

      // 대표 반려동물이 선택되지 않은 경우에만 자동으로 선택된 상태로 설정
      if (selectedPetIds.isEmpty) {
        final primaryPetId = selectedPet?['id'] as String?;
        if (primaryPetId != null) {
          selectedPetIds = {primaryPetId};
        }
      } else {
        // 선택된 반려동물이 삭제되었는지 확인하고, 삭제되었으면 대표 반려동물로 변경
        final existingSelectedIds = selectedPetIds.where((id) {
          return myPets.any((pet) => pet['id'] == id);
        }).toSet();

        if (existingSelectedIds.isEmpty && myPets.isNotEmpty) {
          final primaryPetId = selectedPet?['id'] as String?;
          if (primaryPetId != null) {
            selectedPetIds = {primaryPetId};
          }
        } else {
          selectedPetIds = existingSelectedIds;
        }
      }
    } else {
      // 반려동물이 없으면 선택도 초기화
      selectedPet = null;
      selectedPetIds = {};
    }
    notifyListeners();
  }

  // 반려동물 목록 실시간 스트림 설정
  void setupPetsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 기존 스트림이 있으면 취소
    _petsSubscription?.cancel();

    debugPrint('반려동물 목록 실시간 스트림 설정: $uid');

    // 실시간 스트림 설정
    _petsSubscription = FirebaseFirestore.instance
        .collection('pets')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
        debugPrint('반려동물 목록 업데이트: ${snapshot.docs.length}개');

        // 문서 ID도 함께 저장
        myPets = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // 문서 ID 추가
          return data;
        }).toList();

        _updatePetsList();
      },
      onError: (error) {
        debugPrint('반려동물 목록 스트림 오류: $error');
      },
    );
  }

  // [추가] 최근 산책 기록 로드 (userId 기준 최신 1건) - 단발성
  Future<void> fetchRecentWalk() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('walks')
          .where('userId', isEqualTo: uid)
          .orderBy('endTime', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        recentWalk = snapshot.docs.first.data();
      } else {
        recentWalk = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("최근 산책 기록 로드 실패: $e");
      // 인덱스 오류일 수 있으므로 orderBy 없이 재시도
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('walks')
            .where('userId', isEqualTo: uid)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          // endTime 기준으로 정렬
          final sorted = snapshot.docs.toList();
          sorted.sort((a, b) {
            final aEndTime = (a.data()['endTime'] as Timestamp?)?.toDate() ??
                DateTime(1970);
            final bEndTime = (b.data()['endTime'] as Timestamp?)?.toDate() ??
                DateTime(1970);
            return bEndTime.compareTo(aEndTime);
          });
          recentWalk = sorted.first.data();
        } else {
          recentWalk = null;
        }
        notifyListeners();
      } catch (e2) {
        debugPrint("최근 산책 기록 재시도 실패: $e2");
      }
    }
  }

  // [추가] 최근 산책 기록 실시간 스트림 설정
  void setupRecentWalkStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 기존 스트림이 있으면 취소
    _recentWalkSubscription?.cancel();

    // 실시간 스트림 설정
    _recentWalkSubscription = FirebaseFirestore.instance
        .collection('walks')
        .where('userId', isEqualTo: uid)
        .orderBy('endTime', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          recentWalk = snapshot.docs.first.data();
        } else {
          recentWalk = null;
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('최근 산책 기록 스트림 오류: $error');
        // 인덱스 오류일 수 있으므로 orderBy 없이 재시도
        _setupRecentWalkStreamWithoutOrderBy();
      },
    );
  }

  // orderBy 없이 스트림 설정 (인덱스 오류 대비)
  void _setupRecentWalkStreamWithoutOrderBy() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _recentWalkSubscription?.cancel();

    _recentWalkSubscription = FirebaseFirestore.instance
        .collection('walks')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          // endTime 기준으로 정렬
          final sorted = snapshot.docs.toList();
          sorted.sort((a, b) {
            final aEndTime = (a.data()['endTime'] as Timestamp?)?.toDate() ??
                DateTime(1970);
            final bEndTime = (b.data()['endTime'] as Timestamp?)?.toDate() ??
                DateTime(1970);
            return bEndTime.compareTo(aEndTime);
          });
          recentWalk = sorted.first.data();
        } else {
          recentWalk = null;
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('최근 산책 기록 스트림 재시도 오류: $error');
      },
    );
  }

  // 반려동물 선택/해제 토글
  void togglePetSelection(String petId) {
    if (selectedPetIds.contains(petId)) {
      selectedPetIds.remove(petId);
    } else {
      selectedPetIds.add(petId);
    }
    notifyListeners();
  }

  // 반려동물이 선택되어 있는지 확인
  bool isPetSelected(String petId) {
    return selectedPetIds.contains(petId);
  }

  // [수정] 펫 선택 시 ViewModel에서 상태 관리
  void selectPet(Map<String, dynamic>? pet) {
    selectedPet = pet;
    notifyListeners();
  }

  // [수정] 화면 상태 전환 함수
  void setWalkState(int state) {
    walkState = state;
    notifyListeners();
  }
}
