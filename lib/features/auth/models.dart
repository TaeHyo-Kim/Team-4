import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String bio;
  final String profileImageUrl;
  final bool isLocationPublic;

  // GeoFlutterFire2 호환 구조: {'geohash': '...', 'geopoint': GeoPoint(...)}
  final Map<String, dynamic>? position;

  final DateTime? lastActiveAt;
  final String? fcmToken;
  final List<String> blockedUserIds;
  final UserStats stats;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.bio = '',
    this.profileImageUrl = '',
    this.isLocationPublic = true,
    this.position,
    this.lastActiveAt,
    this.fcmToken,
    this.blockedUserIds = const [],
    required this.stats,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'isLocationPublic': isLocationPublic,
      'position': position,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'fcmToken': fcmToken,
      'blockedUserIds': blockedUserIds,
      'stats': stats.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      nickname: map['nickname'] ?? '',
      bio: map['bio'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      isLocationPublic: map['isLocationPublic'] ?? true,
      position: map['position'],
      lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
      fcmToken: map['fcmToken'],
      blockedUserIds: List<String>.from(map['blockedUserIds'] ?? []),
      stats: UserStats.fromMap(map['stats'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class UserStats {
  final int followerCount;
  final int followingCount;
  final double totalWalkDistance;

  UserStats({this.followerCount = 0, this.followingCount = 0, this.totalWalkDistance = 0.0});

  Map<String, dynamic> toMap() => {
    'followerCount': followerCount,
    'followingCount': followingCount,
    'totalWalkDistance': totalWalkDistance,
  };

  factory UserStats.fromMap(Map<String, dynamic> map) => UserStats(
    followerCount: map['followerCount'] ?? 0,
    followingCount: map['followingCount'] ?? 0,
    totalWalkDistance: (map['totalWalkDistance'] ?? 0).toDouble(),
  );
}