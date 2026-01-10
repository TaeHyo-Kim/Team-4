import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories.dart';
import 'models.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp 사용을 위해 추가
import 'dart:async';

class PetViewModel with ChangeNotifier {
  final PetRepository _repo = PetRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // Storage 인스턴스

  List<PetModel> _pets = [];
  List<PetModel> get pets => _pets;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  StreamSubscription<List<PetModel>>? _petsSubscription;

  PetViewModel() {
    _setupPetsStream();
  }

  // 실시간 스트림 설정
  void _setupPetsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    _petsSubscription?.cancel();
    _petsSubscription = _repo.petsStream(uid).listen(
      (pets) {
        // 대표 반려동물이 리스트 맨 위로 오도록 정렬
        _pets = pets;
        _pets.sort((a, b) => (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0));
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        print("펫 스트림 오류: $error");
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _petsSubscription?.cancel();
    super.dispose();
  }

  // [도움함수] 이미지 업로드 로직 (중복 제거)
  Future<String?> _uploadPetImage(File imageFile) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      // 파일명을 고유하게 생성 (시간값 + uid)
      String fileName = "${DateTime.now().millisecondsSinceEpoch}_$uid.png";

      // pets/ 폴더 안에 사용자별로 관리
      Reference ref = _storage.ref().child('pets/$uid/$fileName');

      // 실제 업로드
      // 10초 동안 응답이 없으면 에러를 발생시킵니다.
      UploadTask uploadTask = ref.putFile(imageFile);

      // timeout을 추가하여 무한 로딩을 방지합니다.
      TaskSnapshot snapshot = await uploadTask.timeout(const Duration(seconds: 15));

      // 업로드된 이미지의 URL 반환
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("이미지 업로드 에러: $e");
      return null;
    }
  }

  // 내 펫 목록 불러오기 (단발성 쿼리 - 필요시 사용)
  Future<void> fetchMyPets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 스트림이 이미 설정되어 있으므로 재설정
    _setupPetsStream();
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

      // -------------------------------------------------------
      // [추가된 로직] 대표 동물의 사진을 유저 프로필에 등록
      // -------------------------------------------------------
      // 리스트에서 새로 선택된 펫 객체를 찾습니다.
      final selectedPet = _pets.firstWhere((p) => p.id == newPrimaryId);

      // 만약 펫에게 이미지 URL이 있다면 유저 컬렉션 업데이트
      if (selectedPet.imageUrl.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({
          'profileImageUrl': selectedPet.imageUrl, // 유저 모델의 필드명과 일치해야 함
        });
        print("유저 프로필 이미지가 ${selectedPet.name}의 사진으로 변경되었습니다.");
      }
      // -------------------------------------------------------

      // 스트림이 자동으로 업데이트하므로 별도 새로고침 불필요

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
    File? imageFile, // 이미지 파일 추가 받음
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      String imageUrl = "";

    // 1. 이미지가 선택되었다면 업로드 먼저 수행
    if (imageFile != null) {
      final uploadedUrl = await _uploadPetImage(imageFile);
      if (uploadedUrl != null) imageUrl = uploadedUrl;
    }

    // 2. DB 저장 (imageUrl 포함)
      await _repo.createPet(
        userId: uid,
        name: name,
        breed: breed,
        weight: weight,
        gender: gender,
        birthDate: birthDate,
        isNeutered: isNeutered,
        imageUrl: imageUrl, // Repository가 이 인자를 받도록 구현되어 있어야 함
      );

      // 스트림이 자동으로 업데이트하므로 별도 새로고침 불필요
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
    File? imageFile, // 이미지 파일 추가 받음
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

      // 새 이미지가 선택된 경우에만 업로드 후 URL 업데이트
      if (imageFile != null) {
        final uploadedUrl = await _uploadPetImage(imageFile);
        if (uploadedUrl != null) {
          updateData['imageUrl'] = uploadedUrl;
        }
      }

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
      // 스트림이 자동으로 업데이트하므로 별도 제거 불필요
    } catch (e) {
      print("삭제 실패: $e");
      rethrow;
    }
  }
}