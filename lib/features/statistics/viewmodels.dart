import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class StatViewModel extends ChangeNotifier {
  bool isLoading = true;
  List<WalkRecord> records = [];
  Map<String, String> petNames = {}; // ID -> 이름 매핑

  // UI 상태 관리 (일일/월별 모드)
  bool isMonthly = false;

  StreamSubscription<User?>? _authSubscription;

  StatViewModel() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        fetchStatistics();
      } else {
        isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void toggleMode(bool monthly) {
    isMonthly = monthly;
    notifyListeners();
  }

  Future<void> fetchStatistics() async {
    isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // [핵심] 산책(Walk)에서 저장할만한 모든 경로를 다 찾아봅니다.
      // 1. users/{uid}/walks (유저 하위)
      final task1 = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('walks')
          .get();

      // 2. walks (최상위 - 복수형)
      final task2 = FirebaseFirestore.instance
          .collection('walks')
          .where('userId', isEqualTo: user.uid)
          .get();

      // 3. walk (최상위 - 단수형, 혹시 몰라서 추가)
      final task3 = FirebaseFirestore.instance
          .collection('walk')
          .where('userId', isEqualTo: user.uid)
          .get();

      final results = await Future.wait([task1, task2, task3]);
      final uniqueDocs = <String, QueryDocumentSnapshot>{};

      // 모든 결과 합치기
      for (var snapshot in results) {
        for (var doc in snapshot.docs) uniqueDocs[doc.id] = doc;
      }

      print("📊 총 발견된 산책 기록: ${uniqueDocs.length}개");

      records = uniqueDocs.values.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        Timestamp parseTimestamp(dynamic val) {
          if (val is Timestamp) return val;
          return Timestamp.now();
        }

        return WalkRecord(
          id: doc.id,
          startTime: parseTimestamp(data['startTime']),
          endTime: parseTimestamp(data['endTime']),
          duration: (data['duration'] as num?)?.toInt() ?? 0,
          distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
          petIds: List<String>.from(data['petIds'] ?? []),
          savedPetNames: List<String>.from(data['petNames'] ?? []),
          emoji: data['emoji'] as String? ?? '🐕',
          memo: data['memo'] as String? ?? '',
          photoUrls: List<String>.from(data['photoUrls'] ?? []),
        );
      }).toList();

      records.sort((a, b) => b.startTime.compareTo(a.startTime));

      // 펫 이름 매칭 준비
      await _fetchPetNames(user.uid);

    } catch (e) {
      print("통계 로드 에러: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchPetNames(String uid) async {
    try {
      // 1. PetModel (pets 컬렉션)
      final snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('ownerId', isEqualTo: uid)
          .get();

      for (var doc in snapshot.docs) {
        final pet = PetModel.fromDocument(doc);
        petNames[pet.id] = pet.name.isNotEmpty ? pet.name : '이름 없음';
      }

      // 2. 레거시 (users/{uid}/pets)
      final legacySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('pets')
          .get();

      for (var doc in legacySnapshot.docs) {
        if (!petNames.containsKey(doc.id)) {
          petNames[doc.id] = doc.data()['name'] as String? ?? '이름 없음';
        }
      }
      notifyListeners();
    } catch (e) {
      print("펫 이름 로드 실패: $e");
    }
  }

  // --- UI 분석 데이터 ---

  List<Map<String, dynamic>> get chartData {
    final now = DateTime.now();
    List<Map<String, dynamic>> data = [];

    if (!isMonthly) {
      // 최근 7일
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dateStr = _dateToString(day);
        double dailyTotal = 0;
        for (var r in records) {
          if (_dateToString(r.startTime.toDate()) == dateStr) dailyTotal += r.distance;
        }
        data.add({'label': "${day.day}일", 'value': dailyTotal, 'isToday': i == 0});
      }
    } else {
      // 이번 달
      final lastDay = DateTime(now.year, now.month + 1, 0);
      for (int i = 1; i <= lastDay.day; i++) {
        final day = DateTime(now.year, now.month, i);
        if (day.isAfter(now)) break;
        final dateStr = _dateToString(day);
        double dailyTotal = 0;
        for (var r in records) {
          if (_dateToString(r.startTime.toDate()) == dateStr) dailyTotal += r.distance;
        }
        data.add({'label': "$i", 'value': dailyTotal, 'isToday': i == now.day});
      }
    }
    return data;
  }

  Map<String, dynamic> get dailyAnalysis {
    final now = DateTime.now();
    final todayStr = _dateToString(now);
    final yesterdayStr = _dateToString(now.subtract(const Duration(days: 1)));

    double todayDist = 0;
    double yesterdayDist = 0;
    Map<String, int> petCounts = {};

    for (var r in records) {
      final rDateStr = _dateToString(r.startTime.toDate());
      if (rDateStr == todayStr) {
        todayDist += r.distance;
        List<String> names = r.savedPetNames.isNotEmpty
            ? r.savedPetNames
            : r.petIds.map((id) => petNames[id] ?? '알 수 없음').toList();
        for (var name in names) petCounts[name] = (petCounts[name] ?? 0) + 1;
      } else if (rDateStr == yesterdayStr) {
        yesterdayDist += r.distance;
      }
    }

    double diff = todayDist - yesterdayDist;
    String diffText = diff >= 0
        ? "어제보다 ${diff.toStringAsFixed(1)}km 많이 산책했습니다."
        : "어제보다 ${diff.abs().toStringAsFixed(1)}km 적게 산책했습니다.";
    if (diff == 0) diffText = "어제와 동일하게 산책했습니다.";

    return {'diffText': diffText, 'petCounts': petCounts, 'todayDist': todayDist};
  }

  Map<String, dynamic> get monthlyAnalysis {
    final now = DateTime.now();
    final monthPrefix = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    double totalDist = 0;
    int totalSeconds = 0;
    Set<String> activeDates = {};
    Map<String, Map<String, dynamic>> petStats = {};

    for (var r in records) {
      if (_dateToString(r.startTime.toDate()).startsWith(monthPrefix)) {
        activeDates.add(_dateToString(r.startTime.toDate()));
        totalDist += r.distance;
        totalSeconds += r.duration;

        List<String> names = r.savedPetNames.isNotEmpty
            ? r.savedPetNames
            : r.petIds.map((id) => petNames[id] ?? '알 수 없음').toList();

        for (var name in names) {
          petStats.putIfAbsent(name, () => {'dist': 0.0, 'time': 0});
          petStats[name]!['dist'] += r.distance;
          petStats[name]!['time'] += r.duration;
        }
      }
    }

    return {
      'month': now.month, 'totalDays': now.day, 'activeDays': activeDates.length,
      'totalDist': totalDist, 'totalTime': _formatDuration(totalSeconds), 'petStats': petStats
    };
  }

  String _dateToString(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  String _formatDuration(int s) => "${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}";
}

class WalkRecord {
  final String id;
  final Timestamp startTime;
  final Timestamp endTime;
  final int duration;
  final double distance;
  final List<String> petIds;
  final List<String> savedPetNames;
  final String emoji;
  final String memo;
  final List<String> photoUrls;

  WalkRecord({
    required this.id, required this.startTime, required this.endTime,
    required this.duration, required this.distance, required this.petIds,
    this.savedPetNames = const [], this.emoji = '🐕', this.memo = '', this.photoUrls = const [],
  });
}

class PetModel {
  final String id; final String ownerId; final String name;
  PetModel({required this.id, required this.ownerId, required this.name});
  factory PetModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PetModel(id: doc.id, ownerId: data['ownerId'] ?? '', name: data['name'] ?? '');
  }
}