import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 알림 서비스
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static int _notificationId = 0;

  /// FCM 토큰 가져오기 및 저장
  Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
      }
      return token;
    } catch (e) {
      debugPrint("FCM 토큰 가져오기 실패: $e");
      return null;
    }
  }

  /// FCM 토큰을 Firestore에 저장
  Future<void> _saveFCMToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("FCM 토큰 저장 실패: $e");
    }
  }

  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  /// 초기화 및 알림 핸들러 설정
  Future<void> initialize() async {
    // 로컬 알림 초기화
    await _initializeLocalNotifications();

    // 알림 권한 요청
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('사용자가 알림 권한을 승인했습니다.');
      await getFCMToken();
      setupNotificationListener();
    } else {
      debugPrint('사용자가 알림 권한을 거부했습니다.');
    }

    // 포그라운드 알림 핸들러
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('포그라운드 알림 수신: ${message.notification?.title}');
      _showLocalNotification(
        message.notification?.title ?? '알림',
        message.notification?.body ?? '',
      );
    });

    // 백그라운드 알림 클릭 핸들러
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('백그라운드 알림 클릭: ${message.notification?.title}');
      // 알림 클릭 시 처리 로직
    });
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('알림 클릭: ${response.payload}');
      },
    );

    // Android 알림 채널 생성 (Android 8.0 이상)
    const androidChannel = AndroidNotificationChannel(
      'default_channel',
      '알림',
      description: '앱 알림 채널',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      '알림',
      channelDescription: '앱 알림 채널',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _notificationId++,
      title,
      body,
      details,
    );
  }

  /// Firestore 알림 리스너 설정
  void setupNotificationListener() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 기존 리스너가 있으면 취소
    _notificationSubscription?.cancel();

    // 실시간으로 알림 감지
    String? lastNotificationId;
    
    _notificationSubscription = _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final notificationId = doc.id;
        
        // 중복 알림 방지
        if (lastNotificationId == notificationId) return;
        lastNotificationId = notificationId;
        
        final notification = doc.data();
        final title = notification['title'] as String? ?? '알림';
        final body = notification['body'] as String? ?? '';
        
        debugPrint('새 알림 수신: $title - $body');
        
        // 실제 로컬 알림 표시
        _showLocalNotification(title, body);
      }
    });
  }

  /// 리스너 정리
  void dispose() {
    _notificationSubscription?.cancel();
  }

  /// 팔로우 알림 전송
  Future<void> sendFollowNotification({
    required String followerId,
    required String followedUserId,
    required String followerNickname,
  }) async {
    try {
      // 팔로우받은 사용자의 FCM 토큰 가져오기
      final followedUserDoc = await _db.collection('users').doc(followedUserId).get();
      if (!followedUserDoc.exists) return;

      final fcmToken = followedUserDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null) return;

      // 알림 데이터 저장 (Firebase Functions에서 처리하거나 직접 전송)
      await _db.collection('notifications').add({
        'userId': followedUserId,
        'type': 'follow',
        'fromUserId': followerId,
        'fromUserNickname': followerNickname,
        'title': '$followerNickname님이 팔로우했습니다',
        'body': '새로운 팔로워가 생겼습니다',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 실제 푸시 알림은 Firebase Functions에서 처리하거나
      // 여기서 직접 전송할 수 있습니다 (서버 키 필요)
    } catch (e) {
      debugPrint("팔로우 알림 전송 실패: $e");
    }
  }

  /// 피드 업로드 알림 전송 (팔로워들에게)
  Future<void> sendFeedNotification({
    required String userId,
    required String userNickname,
    required String postId,
  }) async {
    try {
      // 해당 사용자의 팔로워 목록 가져오기
      final followersSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();

      if (followersSnapshot.docs.isEmpty) return;

      final batch = _db.batch();

      // 각 팔로워에게 알림 생성
      for (final followerDoc in followersSnapshot.docs) {
        final followerId = followerDoc.id;

        final notificationRef = _db.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': followerId,
          'type': 'feed',
          'fromUserId': userId,
          'fromUserNickname': userNickname,
          'postId': postId,
          'title': '$userNickname님이 새 피드를 올렸습니다',
          'body': '새로운 게시물을 확인해보세요',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // 실제 푸시 알림은 Firebase Functions에서 처리합니다
    } catch (e) {
      debugPrint("피드 알림 전송 실패: $e");
    }
  }

  /// 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("알림 읽음 처리 실패: $e");
    }
  }
}

