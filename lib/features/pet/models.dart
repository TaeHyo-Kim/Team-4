import 'package:cloud_firestore/cloud_firestore.dart';

class PetModel {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final Timestamp birthDate;
  final String gender;
  final double weight;
  final bool isNeutered;
  final String imageUrl;
  final bool isRepresentative;

  PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.birthDate,
    required this.gender,
    required this.weight,
    required this.isNeutered,
    this.imageUrl = '',
    this.isRepresentative = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'breed': breed,
      'birthDate': birthDate,
      'gender': gender,
      'weight': weight,
      'isNeutered': isNeutered,
      'imageUrl': imageUrl,
      'isRepresentative': isRepresentative,
    };
  }
}