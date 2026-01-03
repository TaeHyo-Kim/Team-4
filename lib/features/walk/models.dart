import 'package:cloud_firestore/cloud_firestore.dart';

class WalkRecordModel {
  final String? id;
  final String userId;
  final List<String> petIds;
  final Timestamp startTime;
  final Timestamp endTime;
  final int duration;       // 초 단위
  final double distance;    // km 단위
  final double calories;
  final String encodedPath; // 지도 경로 (Polyline)
  final GeoPoint startLocation;
  final String startGeohash;
  final String memo;
  final String emoji;
  final String visibility;  // public, private, friends

  // [추가된 필드]
  final List<String> photoUrls; // 인증샷 리스트
  final int likeCount;          // 좋아요 수

  WalkRecordModel({
    this.id,
    required this.userId,
    required this.petIds,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distance,
    required this.calories,
    required this.encodedPath,
    required this.startLocation,
    required this.startGeohash,
    required this.memo,
    required this.emoji,
    required this.visibility,
    this.photoUrls = const [], // 기본값 빈 리스트
    this.likeCount = 0,        // 기본값 0
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'petIds': petIds,
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'distance': distance,
      'calories': calories,
      'encodedPath': encodedPath,
      'startLocation': startLocation,
      'startGeohash': startGeohash,
      'memo': memo,
      'emoji': emoji,
      'visibility': visibility,
      'photoUrls': photoUrls,
      'likeCount': likeCount,
    };
  }

  factory WalkRecordModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkRecordModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      petIds: List<String>.from(data['petIds'] ?? []),
      startTime: data['startTime'] ?? Timestamp.now(),
      endTime: data['endTime'] ?? Timestamp.now(),
      duration: data['duration'] ?? 0,
      distance: (data['distance'] ?? 0).toDouble(),
      calories: (data['calories'] ?? 0).toDouble(),
      encodedPath: data['encodedPath'] ?? '',
      startLocation: data['startLocation'] ?? const GeoPoint(0, 0),
      startGeohash: data['startGeohash'] ?? '',
      memo: data['memo'] ?? '',
      emoji: data['emoji'] ?? '',
      visibility: data['visibility'] ?? 'public',
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      likeCount: data['likeCount'] ?? 0,
    );
  }
}