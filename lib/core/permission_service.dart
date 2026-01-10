import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 권한 관리 서비스
class PermissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 알림 권한 상태 확인
  Future<ph.PermissionStatus> getNotificationPermissionStatus() async {
    return await ph.Permission.notification.status;
  }

  /// 위치 권한 상태 확인
  Future<ph.PermissionStatus> getLocationPermissionStatus() async {
    return await ph.Permission.location.status;
  }

  /// 갤러리 권한 상태 확인 (이미지)
  Future<ph.PermissionStatus> getPhotosPermissionStatus() async {
    if (await ph.Permission.photos.isGranted) {
      return ph.PermissionStatus.granted;
    }
    // Android 13 이상은 photos 권한, 미만은 storage 권한
    return await ph.Permission.storage.status;
  }

  /// 카메라 권한 상태 확인
  Future<ph.PermissionStatus> getCameraPermissionStatus() async {
    return await ph.Permission.camera.status;
  }

  /// 알림 권한 요청
  Future<bool> requestNotificationPermission() async {
    final status = await ph.Permission.notification.request();
    if (status.isGranted) {
      await _savePermissionStatus('notification', true);
    }
    return status.isGranted;
  }

  /// 위치 권한 요청
  Future<bool> requestLocationPermission() async {
    final status = await ph.Permission.location.request();
    if (status.isGranted) {
      await _savePermissionStatus('location', true);
    }
    return status.isGranted;
  }

  /// 이미지 권한 요청 (갤러리)
  Future<bool> requestPhotosPermission() async {
    ph.PermissionStatus status;
    // Android 13 이상은 photos 권한, 미만은 storage 권한
    try {
      // photos 권한을 먼저 시도
      status = await ph.Permission.photos.request();
      if (status.isGranted) {
        await _savePermissionStatus('photos', true);
        return true;
      }
    } catch (e) {
      // photos 권한이 지원되지 않는 경우 storage 권한 사용
      debugPrint("Photos 권한 요청 실패, storage 권한으로 대체: $e");
    }
    
    // storage 권한 요청 (Android 12 이하)
    status = await ph.Permission.storage.request();
    if (status.isGranted) {
      await _savePermissionStatus('photos', true);
    }
    return status.isGranted;
  }

  /// 카메라 권한 요청
  Future<bool> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    if (status.isGranted) {
      await _savePermissionStatus('camera', true);
    }
    return status.isGranted;
  }

  /// 권한 상태를 Firestore에 저장
  Future<void> _savePermissionStatus(String permissionType, bool granted) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'permissions.$permissionType': granted,
        'permissions.${permissionType}UpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("권한 상태 저장 실패: $e");
    }
  }

  /// 사용자의 권한 상태 가져오기
  Future<Map<String, bool>> getUserPermissions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final permissions = data?['permissions'] as Map<String, dynamic>?;
        if (permissions != null) {
          return permissions.map((key, value) => MapEntry(key, value as bool));
        }
      }
    } catch (e) {
      debugPrint("권한 상태 로드 실패: $e");
    }
    return {};
  }

  /// 권한 상태 업데이트
  Future<void> updatePermissionStatus(String permissionType, bool granted) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'permissions.$permissionType': granted,
        'permissions.${permissionType}UpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("권한 상태 업데이트 실패: $e");
      rethrow;
    }
  }

  /// 설정 앱으로 이동
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}
