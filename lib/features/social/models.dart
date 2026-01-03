import 'package:cloud_firestore/cloud_firestore.dart';

class FollowModel {
  final String? id; // Firestore 문서 ID (보통 'followerId_followingId' 조합 사용)
  final String followerId; // 팔로우 하는 사람 (나)
  final String followingId; // 팔로우 받는 사람 (상대방)
  final DateTime createdAt; // 팔로우한 시간

  FollowModel({
    this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  // DB에 저장할 때 (Map 변환)
  Map<String, dynamic> toMap() {
    return {
      'followerId': followerId,
      'followingId': followingId,
      'createdAt': Timestamp.fromDate(createdAt), // DateTime -> Timestamp
    };
  }

  // DB에서 가져올 때 (객체 생성)
  factory FollowModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FollowModel(
      id: doc.id,
      followerId: data['followerId'] ?? '',
      followingId: data['followingId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(), // Timestamp -> DateTime
    );
  }
}