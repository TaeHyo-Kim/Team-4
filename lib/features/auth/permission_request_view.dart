import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/permission_service.dart';
import '../../core/notification_service.dart';

/// 권한 요청 화면 (회원가입 후 표시)
class PermissionRequestView extends StatefulWidget {
  const PermissionRequestView({super.key});

  @override
  State<PermissionRequestView> createState() => _PermissionRequestViewState();
}

class _PermissionRequestViewState extends State<PermissionRequestView> {
  final PermissionService _permissionService = PermissionService();
  final NotificationService _notificationService = NotificationService();

  bool _notificationGranted = false;
  bool _locationGranted = false;
  bool _photosGranted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initializeNotifications();
  }

  Future<void> _checkPermissions() async {
    final notificationStatus = await _permissionService.getNotificationPermissionStatus();
    final locationStatus = await _permissionService.getLocationPermissionStatus();
    final photosStatus = await _permissionService.getPhotosPermissionStatus();

    setState(() {
      _notificationGranted = notificationStatus.isGranted;
      _locationGranted = locationStatus.isGranted;
      _photosGranted = photosStatus.isGranted;
    });
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _permissionService.requestNotificationPermission();
      setState(() {
        _notificationGranted = granted;
        _isLoading = false;
      });
      if (!granted) {
        _showPermissionDeniedDialog('알림');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알림 권한 요청 실패: $e')),
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _permissionService.requestLocationPermission();
      setState(() {
        _locationGranted = granted;
        _isLoading = false;
      });
      if (!granted) {
        _showPermissionDeniedDialog('위치');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 권한 요청 실패: $e')),
      );
    }
  }

  Future<void> _requestPhotosPermission() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _permissionService.requestPhotosPermission();
      setState(() {
        _photosGranted = granted;
        _isLoading = false;
      });
      if (!granted) {
        _showPermissionDeniedDialog('이미지');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 권한 요청 실패: $e')),
      );
    }
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionType 권한이 거부되었습니다'),
        content: Text('설정에서 권한을 허용하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  void _handleContinue() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "권한 설정",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "서비스 이용을 위해\n다음 권한이 필요합니다",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "권한을 허용하면 더 나은 서비스를 이용하실 수 있습니다.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 40),
            
            // 알림 권한
            _buildPermissionCard(
              icon: Icons.notifications_outlined,
              title: "알림",
              description: "팔로우, 댓글 등의 알림을 받을 수 있습니다",
              isGranted: _notificationGranted,
              onTap: _requestNotificationPermission,
            ),
            const SizedBox(height: 16),
            
            // 위치 권한
            _buildPermissionCard(
              icon: Icons.location_on_outlined,
              title: "위치",
              description: "산책 경로 기록 및 주변 사용자 탐색에 필요합니다",
              isGranted: _locationGranted,
              onTap: _requestLocationPermission,
            ),
            const SizedBox(height: 16),
            
            // 이미지 권한
            _buildPermissionCard(
              icon: Icons.image_outlined,
              title: "이미지",
              description: "프로필 사진 및 반려동물 사진 등록에 필요합니다",
              isGranted: _photosGranted,
              onTap: _requestPhotosPermission,
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "다음",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _handleContinue,
              child: Text(
                "나중에 설정하기",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isGranted ? Colors.green : Colors.grey[300]!,
          width: isGranted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGranted ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? Colors.green : Colors.grey[600],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isGranted)
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
