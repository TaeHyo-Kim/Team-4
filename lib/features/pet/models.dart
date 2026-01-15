import 'package:cloud_firestore/cloud_firestore.dart';

class PetModel {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final Timestamp birthDate;
  final String gender;    // 'M' or 'F' 권장
  final String imageUrl;
  final double weight;
  final bool isNeutered;  // 중성화 여부
  final bool isPrimary;   // 대표 반려동물 여부

  PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.birthDate,
    required this.gender,
    required this.imageUrl,
    required this.weight,
    required this.isNeutered,
    this.isPrimary = false, // 기본값은 false
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'breed': breed,
      'birthDate': birthDate,
      'gender': gender,
      'imageUrl': imageUrl,
      'weight': weight,
      'isNeutered': isNeutered,
      'isPrimary': isPrimary,
    };
  }

  factory PetModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PetModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      birthDate: data['birthDate'] ?? Timestamp.now(),
      gender: data['gender'] ?? 'M',
      imageUrl: data['imageUrl'] ?? '',
      weight: (data['weight'] ?? 0).toDouble(), // int나 double 모두 안전하게 처리
      isNeutered: data['isNeutered'] ?? false,
      isPrimary: data['isPrimary'] ?? false,
    );
  }
}