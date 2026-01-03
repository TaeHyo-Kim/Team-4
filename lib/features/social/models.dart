import 'package:cloud_firestore/cloud_firestore.dart';

class FollowModel {
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  FollowModel({
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'followerId': followerId,
      'followingId': followingId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // 조회용 (필요시 사용)
  factory FollowModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FollowModel(
      followerId: data['followerId'] ?? '',
      followingId: data['followingId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}