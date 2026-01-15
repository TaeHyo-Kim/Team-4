import 'package:cloud_firestore/cloud_firestore.dart';

// 유저 통계
class UserStats {
  final double totalWalkDistance;
  final int followerCount;
  final int followingCount;
  final int postCount;

  UserStats({
    this.totalWalkDistance = 0.0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalWalkDistance': totalWalkDistance,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'postCount': postCount,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalWalkDistance: (map['totalWalkDistance'] ?? 0).toDouble(),
      followerCount: map['followerCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      postCount: map['postCount'] ?? 0,
    );
  }
}

// 유저 모델
class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? bio;
  final String? profileImageUrl;
  final String visibility; // [수정] bool에서 String으로 변경 ('all', 'friends', 'none')
  final GeoPoint? position;
  final UserStats stats;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.bio,
    this.profileImageUrl,
    this.visibility = 'all', // 기본값 '모두 허용'
    this.position,
    required this.stats,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'visibility': visibility,
      'position': position,
      'stats': stats.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '알 수 없음',
      bio: data['bio'],
      profileImageUrl: data['profileImageUrl'],
      visibility: data['visibility'] ?? 'all',
      // [수정] Firestore에서 가져온 데이터를 그대로 GeoPoint?로 캐스팅
      position: data['position'] is GeoPoint ? data['position'] as GeoPoint : null,
      stats: UserStats.fromMap(data['stats'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
