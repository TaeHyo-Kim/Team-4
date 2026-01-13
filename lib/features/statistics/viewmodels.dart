import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class StatViewModel extends ChangeNotifier {
  bool isLoading = true;
  List<WalkRecord> records = [];
  Map<String, String> petNames = {}; // 뷰모델 내부용 이름 명부

  // UI 상태 (일일/월별)
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

  // [신규 기능] 펫 삭제 및 관련 산책 기록 정리 (Cascade Delete)
  Future<void> deletePet(String petId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;

    try {
      print("🗑️ 펫 삭제 프로세스 시작: $petId");

      // 1. 펫 문서 삭제 (users/{uid}/pets)
      await firestore.collection('users').doc(user.uid).collection('pets').doc(petId).delete();

      // (혹시 모를 최상위 pets 경로도 삭제 시도)
      try {
        await firestore.collection('pets').doc(petId).delete();
      } catch (_) {}

      // 2. 이 펫이 포함된 모든 산책 기록 찾기 (users/{uid}/walks)
      // 'petIds' 배열에 petId가 포함된 문서 검색
      final walkQuery = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('walks')
          .where('petIds', arrayContains: petId)
          .get();

      print("  - 연관된 산책 기록 ${walkQuery.docs.length}개 발견. 정리 시작...");

      final batch = firestore.batch();
      int batchCount = 0;

      for (var doc in walkQuery.docs) {
        final data = doc.data();
        List<dynamic> petIds = List.from(data['petIds'] ?? []);
        List<dynamic> savedNames = List.from(data['petNames'] ?? []);

        // 펫 ID 제거
        petIds.remove(petId);

        // (참고: savedNames는 이름 문자열이라 정확히 매칭해서 지우기 어렵지만,
        // 보통 petIds와 인덱스가 같다고 가정하거나 생략합니다.
        // 여기서는 ID 기준 처리가 가장 확실하므로 petIds만 처리해도 통계에서 빠집니다.)

        if (petIds.isEmpty) {
          // 남은 펫이 없으면 (혼자 산책한 기록) -> 기록 자체를 삭제
          batch.delete(doc.reference);
          print("    - 기록 삭제 (혼자 산책): ${doc.id}");
        } else {
          // 남은 펫이 있으면 -> 펫 목록만 업데이트 (함께 산책한 기록)
          batch.update(doc.reference, {'petIds': petIds});
          print("    - 기록 수정 (함께 산책): ${doc.id}");
        }

        batchCount++;
      }

      if (batchCount > 0) {
        await batch.commit();
        print("✅ 산책 기록 정리 완료.");
      }

      // 데이터 갱신
      await fetchStatistics();

    } catch (e) {
      print("❌ 펫 삭제 중 오류 발생: $e");
      rethrow;
    }
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
      // 산책 기록 가져오기 (users/{uid}/walks)
      final task1 = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('walks')
          .get();

      // 최상위 walks (Fallback)
      final task2 = FirebaseFirestore.instance
          .collection('walks')
          .where('userId', isEqualTo: user.uid)
          .get();

      final results = await Future.wait([task1, task2]);
      final uniqueDocs = <String, QueryDocumentSnapshot>{};

      for (var snapshot in results) {
        for (var doc in snapshot.docs) uniqueDocs[doc.id] = doc;
      }

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

      // 뷰모델 내부용 이름 매칭 (백업)
      _fetchPetNamesForVM(user.uid);

    } catch (e) {
      print("통계 로드 에러: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchPetNamesForVM(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('ownerId', isEqualTo: uid)
          .get();

      for (var doc in snapshot.docs) {
        final pet = PetModel.fromDocument(doc);
        petNames[pet.id] = pet.name;
      }
      notifyListeners();
    } catch (e) {
      print("펫 이름 로드 실패: $e");
    }
  }
}

// [데이터 모델]

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
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distance,
    required this.petIds,
    this.savedPetNames = const [],
    this.emoji = '🐕',
    this.memo = '',
    this.photoUrls = const [],
  });
}

// [PetModel] 여기서 공용으로 정의하여 사용
class PetModel {
  final String id;
  final String ownerId;
  final String name;

  PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
  });

  factory PetModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String owner = data['ownerId'] ?? data['userId'] ?? '';
    return PetModel(
      id: doc.id,
      ownerId: owner,
      name: data['name'] as String? ?? '이름 미정',
    );
  }
}