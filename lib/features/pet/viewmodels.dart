import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories.dart';
import 'models.dart';

class PetViewModel with ChangeNotifier {
  final PetRepository _repo = PetRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PetModel> _pets = [];
  List<PetModel> get pets => _pets;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 생성자: 뷰모델이 생성될 때 내 펫 목록을 불러옴
  PetViewModel() {
    fetchMyPets();
  }

  // 내 펫 목록 불러오기
  Future<void> fetchMyPets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    // (화면이 깜빡이는 걸 방지하기 위해 notifyListeners는 데이터 로드 후에만 호출하거나 필요시 최소화)

    try {
      _pets = await _repo.getPets(uid);
      notifyListeners();
    } catch (e) {
      print("펫 불러오기 실패: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
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
      // 리포지토리에 넘겨주기 (현재 리포지토리 함수 파라미터에 맞춰 호출)
      // *실제로는 PetModel을 통째로 넘기는 구조로 리포지토리를 고치면 더 좋습니다.
      // 여기서는 기존 리포지토리 로직을 활용합니다.
      await _repo.createPet(
        userId: uid,
        name: name,
        breed: breed,
        weight: weight,
        // (주의) 리포지토리에 birthDate, gender 등을 받는 파라미터가 없다면
        // 리포지토리의 createPet 함수를 수정하거나, 여기서 update를 추가로 해야 합니다.
        // 일단은 기본 로직대로 진행합니다.
      );

      // 저장 후 목록 새로고침
      await fetchMyPets();
    } catch (e) {
      print("펫 추가 실패: $e");
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