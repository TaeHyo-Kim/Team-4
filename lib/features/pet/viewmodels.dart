import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart';
import 'models.dart';

class PetViewModel with ChangeNotifier {
  final PetRepository _repo = PetRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PetModel> _pets = [];
  List<PetModel> get pets => _pets;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  PetViewModel() {
    fetchMyPets();
  }

  // 내 펫 목록 불러오기
  Future<void> fetchMyPets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    try {
      _pets = await _repo.getPets(uid);

      // 대표 반려동물이 리스트 맨 위로 오도록 정렬
      _pets.sort((a, b) => (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0));

      notifyListeners();
    } catch (e) {
      print("펫 불러오기 실패: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 대표 반려동물 설정
  Future<void> setPrimaryPet(String newPrimaryId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. 기존 대표 반려동물 해제
      for (var pet in _pets) {
        if (pet.isPrimary && pet.id != newPrimaryId) {
          await _repo.updatePet(pet.id, {'isPrimary': false});
        }
      }

      // 2. 새로운 펫 대표 설정
      await _repo.updatePet(newPrimaryId, {'isPrimary': true});

      // 3. 목록 새로고침
      await fetchMyPets();

    } catch (e) {
      print("대표 펫 설정 실패: $e");
      rethrow;
    }
  }

  // 펫 추가하기
  Future<void> addPet({
    required String name,
    required String breed,
    required String gender,
    required DateTime birthDate,
    required double weight,
    required bool isNeutered,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _repo.createPet(
        userId: uid,
        name: name,
        breed: breed,
        weight: weight,
        gender: gender,
        birthDate: birthDate,
        isNeutered: isNeutered,
      );

      await fetchMyPets();
    } catch (e) {
      print("펫 추가 실패: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // [추가됨] 펫 정보 수정하기
  Future<void> editPet({
    required String petId,
    required String name,
    required String breed,
    required String gender,
    required DateTime birthDate,
    required double weight,
    required bool isNeutered,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 업데이트할 데이터 맵 생성
      final updateData = {
        'name': name,
        'breed': breed,
        'gender': gender,
        'birthDate': birthDate, // Timestamp 변환은 Model/Repo 로직에 따라 자동 처리됨을 가정하거나, Repo가 dynamic Map 처리
        'weight': weight,
        'isNeutered': isNeutered,
      };

      await _repo.updatePet(petId, updateData);
      await fetchMyPets(); // 목록 갱신
    } catch (e) {
      print("펫 수정 실패: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 펫 삭제
  Future<void> deletePet(String petId) async {
    try {
      await _repo.deletePet(petId);
      _pets.removeWhere((pet) => pet.id == petId);
      notifyListeners();
    } catch (e) {
      print("삭제 실패: $e");
      rethrow;
    }
  }
}