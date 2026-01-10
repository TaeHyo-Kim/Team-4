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

class WalkViewModel with ChangeNotifier {
  final WalkRepository _repo = WalkRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ------------------------------------------------------------------------
  // 상태 변수들
  // ------------------------------------------------------------------------

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
    _inactivityTimer = Timer(const Duration(seconds: 10), () {
      _isUserInteracting = false;
      moveToCurrentLocation();
      notifyListeners();
    });
  }

  // 현재 위치로 카메라 이동 (배율 15.0 고정)
  Future<void> moveToCurrentLocation() async {
    if (_currentPosition != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: _defaultZoom,
          ),
        ),
      );
    }
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

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      if (_isPaused) return;
      if (position.accuracy > _accuracyThreshold) return;

      final newPoint = LatLng(position.latitude, position.longitude);

      // [추가] 로컬 DB에 즉시 저장
      await WalkDbHelper.instance.insertPoint(newPoint.latitude, newPoint.longitude);

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
    if (!_isWalking && walkState != 2) return;

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
  // Helper: 칼로리 계산 (간단 공식)
  // ------------------------------------------------------------------------
  double _calculateCalories(double distanceMeters) {
    // 60kg 성인이 걷기 운동 시 약 0.05kcal/m 소모한다고 가정
    // (정확한 계산을 위해선 유저 몸무게 데이터가 필요함)
    return distanceMeters * 0.05;
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

  // 후기 작성 관련 메서드
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      reviewImages.add(image);
      currentImageIndex = reviewImages.length - 1;
      notifyListeners();
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
      final Paint paint = Paint()..isAntiAlias = true;
      final double radius = 80.0; // 반지름 (가로세로 160의 절반)

      // 원형 클리핑 및 이미지 그리기
      canvas.drawCircle(Offset(radius, radius), radius, paint);
      paint.blendMode = BlendMode.srcIn;
      canvas.drawImage(image, Offset.zero, paint);

      // 3. 최종 비트맵 변환
      final ui.Image finalImage = await pictureRecorder.endRecording().toImage(160, 160);
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
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
    _positionStream?.cancel();
    walkState = 2; // 요약 화면으로 이동
    notifyListeners();
  }

  // 산책 종료 및 저장 (후기 포함)
  Future<void> stopWalkAndSave(String memo) async {
    if (!_isWalking && walkState != 2) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // 이미지 업로드
    List<String> photoUrls = [];
    if (reviewImages.isNotEmpty) {
      final storage = FirebaseStorage.instance;
      for (final imageFile in reviewImages) {
        try {
          final ref = storage
              .ref()
              .child('walks/${userId}/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}');
          await ref.putFile(File(imageFile.path));
          final url = await ref.getDownloadURL();
          photoUrls.add(url);
        } catch (e) {
          debugPrint("이미지 업로드 실패: $e");
        }
      }
    }

    // stopWalk 호출하여 저장
    await stopWalk(
      memo: memo,
      emoji: selectedEmoji,
      visibility: 'public',
      photoUrls: photoUrls,
    );

    // 상태 초기화
    walkState = 0; // 홈으로 복귀
    reviewImages.clear();
    currentImageIndex = 0;
    reviewController.clear();
    selectedEmoji = '👍';
    endTime = null;
    notifyListeners();
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
    reviewController.dispose();
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
    await fetchMyPets();
    await fetchRecentWalk();
    await fetchCurrentLocation();

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

  // 내 반려동물 목록 가져오기 (isPrimary 기준 정렬)
  Future<void> fetchMyPets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

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

    // isPrimary가 true인 동물을 우선 정렬
    myPets.sort((a, b) {
      final aPrimary = a['isPrimary'] == true ? 1 : 0;
      final bPrimary = b['isPrimary'] == true ? 1 : 0;
      return bPrimary.compareTo(aPrimary);
    });

    if (myPets.isNotEmpty) {
      // 대표 반려동물을 기본값으로 설정
      selectedPet = myPets.firstWhere((p) => p['isPrimary'] == true, orElse: () => myPets.first);
      
      // 대표 반려동물을 자동으로 선택된 상태로 설정
      final primaryPetId = selectedPet?['id'] as String?;
      if (primaryPetId != null) {
        selectedPetIds = {primaryPetId};
      }
    }
    notifyListeners();
  }

  // [추가] 최근 산책 기록 로드 (userId 기준 최신 1건)
  Future<void> fetchRecentWalk() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('walks')
        .where('userId', isEqualTo: uid)
        .orderBy('endTime', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      recentWalk = snapshot.docs.first.data();
      notifyListeners();
    }
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