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

    return Scaffold(
      body: Stack(
        children: [
          // [1] 지도 (배경)
          _buildGoogleMap(vm),

          // [2] 정보 카드 (상단)
          if (vm.isWalking)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: WalkInfoCard(
                seconds: vm.seconds,
                distanceMeters: vm.distance,
              ),
            ),

          // [3] 컨트롤 패널 (하단)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: WalkControls(
              isWalking: vm.isWalking,
              isPaused: vm.isPaused,
              onStart: () async {
                try {
                  // TODO: 실제로는 펫 선택 화면에서 ID를 받아와야 함
                  await vm.startWalk(['pet_dummy_id']);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("시작 실패: $e")),
                  );
                }
              },
              onPauseToggle: vm.togglePause,
              onStop: () => _showStopDialog(context, vm),
            ),
          ),

          // [4] 로딩 중 (위치 못 잡음)
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

  // 구글 맵 위젯
  Widget _buildGoogleMap(WalkViewModel vm) {
    if (vm.currentPosition == null) return const SizedBox();

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: vm.currentPosition!,
        zoom: 17,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      polylines: {
        Polyline(
          polylineId: const PolylineId("route"),
          points: vm.route,
          color: Colors.blueAccent,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      },
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("저장 실패: $e")),
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
    final km = (distanceMeters / 1000).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
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
          children: [
            Icon(icon, size: 20, color: Colors.amber),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// 2. 컨트롤 버튼
class WalkControls extends StatelessWidget {
  final bool isWalking;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPauseToggle;
  final VoidCallback onStop;

  const WalkControls({
    super.key,
    required this.isWalking,
    required this.isPaused,
    required this.onStart,
    required this.onPauseToggle,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWalking) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          label: const Text("산책 시작", style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
            elevation: 5,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton.large(
          heroTag: "pause_btn",
          onPressed: onPauseToggle,
          backgroundColor: Colors.white,
          child: Icon(
            isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.amber,
            size: 32,
          ),
        ),
        const SizedBox(width: 20),
        FloatingActionButton.large(
          heroTag: "stop_btn",
          onPressed: onStop,
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.stop, color: Colors.white, size: 32),
        ),
      ],
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