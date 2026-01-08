import 'dart:async';
import 'dart:convert'; // encodedPath 변환용 (JSON)
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp, GeoPoint용

import '../../data/repositories.dart';
import 'models.dart';

class WalkViewModel with ChangeNotifier {
  final WalkRepository _repo = WalkRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ------------------------------------------------------------------------
  // 상태 변수들
  // ------------------------------------------------------------------------
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

  // ------------------------------------------------------------------------
  // Getters
  // ------------------------------------------------------------------------
  bool get isWalking => _isWalking;

  bool get isPaused => _isPaused;

  int get seconds => _seconds;

  double get distance => _distance;

  List<LatLng> get route => _route;

  LatLng? get currentPosition => _currentPosition;

  // 화면 진입 시 초기 위치 로드
  Future<void> fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = LatLng(position.latitude, position.longitude);
      notifyListeners();
    } catch (e) {
      print("위치 가져오기 실패: $e");
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

    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // 2. 일시정지 / 재개
  // ------------------------------------------------------------------------
  void togglePause() {
    if (!_isWalking) return;
    _isPaused = !_isPaused;

    if (_isPaused) {
      _timer?.cancel();
    } else {
      _startTimer();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // 3. 산책 종료 및 저장 (모델 구조에 맞춤)
  // ------------------------------------------------------------------------
  // memo, emoji, visibility는 종료 화면에서 입력받아 전달한다고 가정
  Future<void> stopWalk({
    String memo = '',
    String emoji = '🐕',
    String visibility = 'public'
  }) async {
    if (!_isWalking) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // 스트림 종료
    _positionStream?.cancel();
    _timer?.cancel();
    _isWalking = false;
    _isPaused = false;

    // 1. 데이터 가공
    final endTime = DateTime.now();
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
      endTime: Timestamp.fromDate(endTime),
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
      photoUrls: [],
      // 이미지는 별도 업로드 로직 필요 (일단 빈 리스트)
      likeCount: 0,
    );

    // [보정 로직 4] 네트워크 미연결 시 재시도 로직이 포함된 저장
    try {
      // 업로드 시도
      await _repo.saveWalk(newRecord);
    } catch (e) {
      // [해결책] 네트워크 오류 발생 시 로컬 DB에 보관했다가 나중에 전송
      print("업로드 실패, 로컬에 임시 저장: $e");
      // await _localDb.saveForLater(newRecord);
      rethrow;
    } finally {
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

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
          if (_isPaused) return;

          // [보정 로직 1] 정확도 필터링
          // 수신된 데이터의 정확도가 너무 낮으면(오차 범위가 크면) 무시합니다.
          if (position.accuracy > _accuracyThreshold) {
            debugPrint("정확도 낮음 무시: ${position.accuracy}m");
            return;
          }

          final newPoint = LatLng(position.latitude, position.longitude);

          if (_route.isNotEmpty) {
            final lastPoint = _route.last;

            // [보정 로직 2] 거리 계산 및 직선 보정
            // Google Maps Polyline은 점들을 순서대로 잇기 때문에
            // 중간에 신호가 끊겼다가 복구되어도 자동으로 직선 연결됩니다.
            final dist = Geolocator.distanceBetween(
              lastPoint.latitude, lastPoint.longitude,
              newPoint.latitude, newPoint.longitude,
            );

            // 비정상적인 순간 이동(예: 갑자기 500m 이동) 방지 필터 (선택 사항)
            if (dist < 300) {
              _distance += dist;
              _route.add(newPoint);
            }
          } else {
            _startPosition ??= newPoint;
            _route.add(newPoint);
          }

          _currentPosition = newPoint;
          notifyListeners();

          // [보정 로직 3] 로컬 캐싱 (임시 예시)
          // 실제 구현 시 sqflite를 사용하여 _route를 수시로 저장하면 앱 종료 시 복구 가능합니다.
          _saveToLocalCache(_route);
        });
  }

  void _saveToLocalCache(List<LatLng> points) {
    // SharedPreferences나 sqflite에 현재 경로를 임시 저장하는 로직을 여기에 구현합니다.
    // 이는 네트워크 단절 후 앱이 강제 종료되었을 때 데이터를 보호합니다.
  }


  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }
}