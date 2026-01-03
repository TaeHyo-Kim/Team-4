import 'package:cloud_firestore/cloud_firestore.dart';

class WalkRecordModel {
  final String userId;
  final List<String> petIds;
  final Timestamp startTime;
  final Timestamp endTime;
  final int duration;
  final double distance;
  final double calories;
  final String encodedPath;
  final GeoPoint startLocation;
  final String startGeohash;
  final String memo;
  final String emoji;
  final List<String> photoUrls;
  final String visibility;
  final int likeCount;

  WalkRecordModel({
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
    this.memo = '',
    this.emoji = '😀',
    this.photoUrls = const [],
    this.visibility = 'public',
    this.likeCount = 0,
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
      'photoUrls': photoUrls,
      'visibility': visibility,
      'likeCount': likeCount,
    };
  }
}