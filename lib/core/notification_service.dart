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
  String? _lastNotificationId;
  final Set<String> _processedNotificationIds = <String>{};
  DateTime? _listenerSetupTime; // 리스너 설정 시간
  String? _currentUserId; // 현재 리스너가 설정된 사용자 ID

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
      // 권한이 없어도 Firestore 리스너는 설정 (로컬 알림은 안되지만 데이터는 받을 수 있음)
      setupNotificationListener();
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

    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('알림 클릭: ${response.payload}');
      },
    );

    debugPrint('로컬 알림 초기화 결과: $initialized');

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
    
    // Android에서 알림 권한 요청
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      debugPrint('Android 알림 권한 요청 결과: $granted');
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(String title, String body) async {
    try {
      debugPrint('로컬 알림 표시 시도: $title - $body');
      
      // Android에서 알림 권한 확인
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        debugPrint('로컬 알림 권한 상태: $granted');
        if (granted == false) {
          debugPrint('로컬 알림 권한이 거부되어 알림을 표시할 수 없습니다.');
          return;
        }
      }

      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        '알림',
        channelDescription: '앱 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
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

      final notificationId = _notificationId++;
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
      );
      
      debugPrint('로컬 알림 표시 완료: ID=$notificationId, Title=$title');
    } catch (e, stackTrace) {
      debugPrint('로컬 알림 표시 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }

  /// Firestore 알림 리스너 설정
  void setupNotificationListener() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('사용자가 로그인되어 있지 않아 알림 리스너를 설정할 수 없습니다.');
      return;
    }

    // 같은 사용자이고 리스너가 이미 설정되어 있으면 재설정하지 않음
    if (_currentUserId == uid && _notificationSubscription != null) {
      debugPrint('알림 리스너가 이미 설정되어 있습니다: $uid');
      return;
    }

    // 사용자가 바뀌었거나 리스너가 없으면 재설정
    if (_currentUserId != uid) {
      _processedNotificationIds.clear();
      _currentUserId = uid;
    }

    // 기존 리스너가 있으면 취소
    _notificationSubscription?.cancel();
    
    // 리스너 설정 시간 기록 (이 시간 이후에 생성된 알림만 처리)
    _listenerSetupTime = DateTime.now();

    debugPrint('알림 리스너 설정 시작: $uid (설정 시간: $_listenerSetupTime)');
    
    // 실시간으로 알림 감지 - 변경사항만 감지하도록 수정
    // 인덱스 오류 방지를 위해 orderBy 없이 먼저 시도
    _notificationSubscription = _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      debugPrint('알림 스냅샷 수신: ${snapshot.docs.length}개, 변경사항: ${snapshot.docChanges.length}개');
      
      // 새로 추가된 알림만 처리
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          final notificationId = docChange.doc.id;
          
          // 이미 처리한 알림인지 확인
          if (_processedNotificationIds.contains(notificationId)) {
            debugPrint('이미 처리한 알림 스킵: $notificationId');
            continue;
          }
          
          final notification = docChange.doc.data();
          if (notification == null) {
            debugPrint('알림 데이터가 null입니다: $notificationId');
            continue;
          }
          
          // 리스너 설정 이후에 생성된 알림만 처리 (초기 로드 시 기존 알림 무시)
          final createdAt = notification['createdAt'] as Timestamp?;
          if (createdAt != null && _listenerSetupTime != null) {
            final createdTime = createdAt.toDate();
            // 리스너 설정 시간보다 5초 이전에 생성된 알림은 무시 (초기 로드 방지)
            if (createdTime.isBefore(_listenerSetupTime!.subtract(const Duration(seconds: 5)))) {
              debugPrint('기존 알림 무시 (리스너 설정 이전): $notificationId, 생성시간: $createdTime');
              _processedNotificationIds.add(notificationId); // 처리 목록에 추가하여 다시 처리하지 않음
              continue;
            }
          }
          
          _processedNotificationIds.add(notificationId);
          
          final title = notification['title'] as String? ?? '알림';
          final body = notification['body'] as String? ?? '';
          
          debugPrint('새 알림 감지 및 표시: ID=$notificationId, Title=$title, Body=$body');
          
          // 실제 로컬 알림 표시
          _showLocalNotification(title, body);
        }
      }
    }, onError: (error) {
      debugPrint('알림 리스너 오류: $error');
      // 에러가 발생해도 리스너는 유지 (일시적인 네트워크 오류일 수 있음)
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
      debugPrint('팔로우 알림 전송 시작: follower=$followerId, followed=$followedUserId, nickname=$followerNickname');
      
      // 팔로우받은 사용자 확인
      final followedUserDoc = await _db.collection('users').doc(followedUserId).get();
      if (!followedUserDoc.exists) {
        debugPrint('팔로우받은 사용자를 찾을 수 없습니다: $followedUserId');
        return;
      }

      debugPrint('팔로우받은 사용자 확인 완료, 알림 저장 시작');

      // 알림 데이터 저장 (FCM 토큰과 관계없이 항상 저장)
      final notificationData = {
        'userId': followedUserId,
        'type': 'follow',
        'fromUserId': followerId,
        'fromUserNickname': followerNickname,
        'title': '$followerNickname님이 팔로우했습니다',
        'body': '새로운 팔로워가 생겼습니다',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      debugPrint('알림 데이터: $notificationData');
      
      final docRef = await _db.collection('notifications').add(notificationData);
      
      debugPrint('팔로우 알림 저장 완료: notificationId=${docRef.id}, userId=$followedUserId');

      // 실제 푸시 알림은 Firebase Functions에서 처리하거나
      // 여기서 직접 전송할 수 있습니다 (서버 키 필요)
    } catch (e, stackTrace) {
      debugPrint("팔로우 알림 전송 실패: $e");
      debugPrint("스택 트레이스: $stackTrace");
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

