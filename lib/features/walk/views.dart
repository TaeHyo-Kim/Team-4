import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'viewmodels.dart';
// widgets.dart import 제거함 (파일 내부에 포함)

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  @override
  void initState() {
    super.initState();
    // 화면 로드 후 위치 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalkViewModel>().fetchCurrentLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WalkViewModel>();

    // 산책 중이 아닐 때 (초기 화면)
    if (!vm.isWalking) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF4CAF50),
          title: const Text(
            "산책",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            // [1] 지도 (배경, 투명도 조정)
            _buildGoogleMap(vm),

            // [2] 메인 컨텐츠
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.95),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // 인사 문구
                    const Text(
                      "오늘도 즐거운 산책 해보아용 >.<",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // START 버튼 (오렌지색 원형)
                    GestureDetector(
                      onTap: () async {
                        try {
                          await vm.startWalk(['pet_dummy_id']);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("시작 실패: $e")),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF9800).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pets,
                              size: 60,
                              color: Colors.white,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "START",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                    // 최근 산책 기록
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "최근 산책 기록",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "어제 : 45분, 3.2km",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // [3] 로딩 중 (위치 못 잡음)
            if (vm.currentPosition == null)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 10),
                      Text("위치를 찾는 중...", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 산책 중일 때
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "산책",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [

          // [1] 지도 영역 (터치 감지)
          Listener(
            onPointerDown: (_) => vm.onUserInteractionStarted(),
            onPointerUp: (_) => vm.onUserInteractionEnded(),
            child: _buildGoogleMap(vm),
          ),

          // [2] 초기 화면 오버레이 (산책 중이 아닐 때)
          if (!vm.isWalking) _buildInitialOverlay(vm),

          // [3] 산책 중 상단 정보 카드
          if (vm.isWalking)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: WalkInfoCard(
                  seconds: vm.seconds, distanceMeters: vm.distance),
            ),

          // [4] 내 위치 버튼 (우측 하단)
          Positioned(
            bottom: vm.isWalking ? 120 : 40,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => vm.moveToCurrentLocation(),
              child: const Icon(Icons.my_location, color: Color(0xFFFF9800)),
            ),
          ),

          // [5] 하단 컨트롤 패널
          if (vm.isWalking)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: WalkControls(
                isWalking: vm.isWalking,
                isPaused: vm.isPaused,
                distanceMeters: vm.distance,
                seconds: vm.seconds,
                onStop: () => _showStopDialog(context, vm),
                onStart: () {}, // 무시
              ),
            ),

          // [6] 로딩 화면
          if (vm.currentPosition == null)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                          "위치를 찾는 중...", style: TextStyle(color: Colors.white)),
                    ]
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 구글 맵 위젯
  Widget _buildGoogleMap(WalkViewModel vm) {
    if (vm.currentPosition == null) return const SizedBox();

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: vm.currentPosition!,
        zoom: 15.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      polylines: {
        Polyline(polylineId: const PolylineId("route"),
          points: vm.route,
          color: const Color(0xFFFF9800),
          width: 6,
          jointType: JointType.round,
        ),
      },
      // [수정] 컨트롤러를 ViewModel에 전달합니다.
      onMapCreated: (controller) => vm.setMapController(controller),
    );
  }

  Widget _buildInitialOverlay(WalkViewModel vm) {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("오늘도 즐거운 산책 해보아용 >.<", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 60),
            GestureDetector(
              onTap: () => vm.startWalk(['pet_dummy_id']),
              child: Container(
                width: 180, height: 180,
                decoration: const BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, size: 50, color: Colors.white),
                    Text("START", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
            // ... 최근 산책 기록 위젯 유지 ...
          ],
        ),
      ),
    );
  }

  // 종료 다이얼로그 띄우기
  void _showStopDialog(BuildContext context, WalkViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WalkFinishDialog(
        onComplete: (memo, emoji, visibility) async {
          try {
            await vm.stopWalk(
              memo: memo,
              emoji: emoji,
              visibility: visibility,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("산책 기록이 저장되었습니다! 🚩")),
              );
            }
          } catch (e) {
            // [수정] 에러 메시지를 구체적으로 표시 (permission-denied 등)
            String errorMsg = e.toString();
            if (errorMsg.contains("permission-denied")) {
              errorMsg = "서버 권한이 거부되었습니다. 관리자에게 문의하세요.";
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("저장 실패: $errorMsg"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}

// ==============================================================================
//  아래부터는 원래 widgets.dart에 있던 내용입니다. (한 파일에 통합)
// ==============================================================================

// 1. 정보 카드
class WalkInfoCard extends StatelessWidget {
  final int seconds;
  final double distanceMeters;

  const WalkInfoCard({
    super.key,
    required this.seconds,
    required this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    final km = (distanceMeters / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItem(Icons.timer, "$minutes:$sec", "시간"),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          _buildItem(Icons.directions_walk, "$km km", "거리"),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFFFF9800)),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// 2. 컨트롤 버튼
class WalkControls extends StatelessWidget {
  final bool isWalking;
  final bool isPaused;
  final double distanceMeters;
  final int seconds;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const WalkControls({
    super.key,
    required this.isWalking,
    required this.isPaused,
    required this.distanceMeters,
    required this.seconds,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWalking) {
      return const SizedBox.shrink(); // 초기 화면에서는 보이지 않음
    }

    // 산책 중일 때 하단 컨트롤 (노란색 배경)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade300, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 산책 중 정보
          Row(
            children: [
              const Text(
                "산책 중..",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${(distanceMeters / 1000).toStringAsFixed(1)}km, ${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          // 산책 종료 버튼
          ElevatedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop, size: 20),
            label: const Text("산책 종료"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 3. 종료 다이얼로그
class WalkFinishDialog extends StatefulWidget {
  final Function(String memo, String emoji, String visibility) onComplete;

  const WalkFinishDialog({super.key, required this.onComplete});

  @override
  State<WalkFinishDialog> createState() => _WalkFinishDialogState();
}

class _WalkFinishDialogState extends State<WalkFinishDialog> {
  final _memoCtrl = TextEditingController();
  String _selectedEmoji = '🐕';
  final String _visibility = 'public';
  final List<String> _emojis = ['🐕', '🐈', '💩', '🏃', '🌳', '☀️'];

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("산책 종료 🐾"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("오늘 산책 어떠셨나요?", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            const Text("기분 선택", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _emojis.map((emoji) {
                  final isSelected = _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.amber) : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(
                labelText: "메모 남기기",
                hintText: "귀여운 강아지를 만났다!",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onComplete(_memoCtrl.text, _selectedEmoji, _visibility);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
          ),
          child: const Text("저장하기"),
        ),
      ],
    );
  }
}