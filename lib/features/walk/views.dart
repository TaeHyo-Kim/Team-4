import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:io';
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
      context.read<WalkViewModel>().initWalkScreen(); // 통합 초기화 호출
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WalkViewModel>();
    return Scaffold(
      appBar: AppBar(
          title: const Text("산책"), backgroundColor: const Color(0xFF4CAF50)),
      body: Listener(
        onPointerDown: (_) => vm.onUserInteractionStarted(),
        onPointerUp: (_) => vm.onUserInteractionEnded(),
        child: _buildBodyByState(vm),
      ),
    );
  }

  Widget _buildBodyByState(WalkViewModel vm) {
    switch (vm.walkState) {
      case 1:
        return _buildWalking(vm);
      case 2:
        return _buildSummary(vm);
      case 3:
        return _buildReview(vm);
      default:
        return _buildHome(vm);
    }
  }

  // [수정 부분 1] 홈 화면 (1번 사진 대응): 발바닥 아이콘 추가 및 최근 기록 레이아웃 최적화
  Widget _buildHome(WalkViewModel vm) {
    return Stack(
      children: [
        Opacity(opacity: 0.3, child: _buildGoogleMap(vm, interaction: false)),
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("오늘도 즐거운 산책 해보아용 >.<",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // 펫 선택 드롭다운
              if (vm.myPets.isNotEmpty)
                DropdownButton<Map<String, dynamic>>(
                  value: vm.selectedPet,
                  items: vm.myPets.map((pet) =>
                      DropdownMenuItem(
                        value: pet,
                        child: Text(pet['name'] ?? '강아지'),
                      )).toList(),
                  onChanged: (val) => vm.selectPet(val),
                ),
              const SizedBox(height: 30),
              // [수정] START 버튼에 발바닥 아이콘 추가
              GestureDetector(
                onTap: () async {
                  // [수정] 시작 시 사용자의 위치를 중심으로 잡아줌 [요구사항 3]
                  await vm.startWalk(['pet_dummy_id']);
                },
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF9800),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.orange.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 5)
                      ]
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets, size: 60, color: Colors.white),
                      // 발바닥 아이콘 복구
                      SizedBox(height: 8),
                      Text("START", style: TextStyle(color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // [수정] 최근 산책 기록 복구 [요구사항 2]
              // [수정] 최근 산책 기록 표시 및 없을 경우 대사 표기 [요구사항 3]
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ]
                ),
                child: vm.recentWalk != null
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("최근 산책 기록", style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text("어제 : ${vm.recentWalk!['duration'] ~/ 60}분, ${(vm
                        .recentWalk!['distance'] as double).toStringAsFixed(
                        1)}km",
                        style: const TextStyle(color: Colors.grey)),
                  ],
                )
                    : const Center(
                  child: Text("아직 산책 기록이 없어요.\n첫 산책을 시작해보세요!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // [수정] 요약 화면: 후기 작성하기 버튼 로직 수정
  Widget _buildSummary(WalkViewModel vm) {
    return Stack(
      children: [
        _buildGoogleMap(vm, interaction: true), // 갱신 중단된 경로 표시
        Positioned(
          bottom: 40, left: 20, right: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("산책 완료! 🎉", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("${(vm.distance / 1000).toStringAsFixed(1)}km, ${vm.seconds ~/ 60}분"),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () {}, child: const Text("지도 확인하기"))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      onPressed: () => vm.setWalkState(3), // [수정] 후기 작성 상태(3)로 변경
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("후기 작성하기"),
                    )),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  // [수정] 후기 작성 UI: 인디케이터 및 화살표 로직 강화
  // [수정] 후기 작성 UI: 화살표 외부 배치, 텍스트 필드, 이모지 선택 효과 추가
  Widget _buildReview(WalkViewModel vm) {
    final TextEditingController _memoController = TextEditingController(text: "");

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text("오늘의 산책은 어떠셨나요?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 왼쪽 화살표 (반투명 로직 유지)
              Opacity(
                opacity: vm.currentImageIndex > 0 ? 1.0 : 0.3,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 30),
                  onPressed: vm.currentImageIndex > 0 ? () => setState(() => vm.currentImageIndex--) : null,
                ),
              ),
              // 이미지 상자 및 삭제 버튼 [요구사항 7]
              Stack(
                children: [
                  Container(
                    width: 250, height: 250,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(15)),
                    child: vm.reviewImages.isEmpty
                        ? const Icon(Icons.image_not_supported, size: 80, color: Colors.grey)
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(File(vm.reviewImages[vm.currentImageIndex].path), fit: BoxFit.cover),
                    ),
                  ),
                  // [추가] 이미지 우상단 X 버튼 [요구사항 7]
                  if (vm.reviewImages.isNotEmpty)
                    Positioned(
                      top: 5, right: 5,
                      child: GestureDetector(
                        onTap: () => vm.removeImage(vm.currentImageIndex),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
              // 오른쪽 화살표 (개수 무제한 대응) [요구사항 2]
              Opacity(
                opacity: vm.currentImageIndex < vm.reviewImages.length - 1 ? 1.0 : 0.3,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 30),
                  onPressed: vm.currentImageIndex < vm.reviewImages.length - 1 ? () => setState(() => vm.currentImageIndex++) : null,
                ),
              ),
            ],
          ),

          // [수정] 인디케이터: 개수 제한 없이 모두 표기 [요구사항 2]
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(vm.totalDots, (index) {
              Color dotColor = Colors.white;
              if (vm.reviewImages.isNotEmpty) {
                dotColor = (index == vm.currentImageIndex) ? Colors.black : Colors.grey;
              }
              return Container(margin: const EdgeInsets.all(5), width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: Colors.black26)));
            }),
          ),
          const SizedBox(height: 20),

          // [3] 산책 후기 텍스트 입력 창 추가 [요구사항 3]
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "산책 후기를 남겨주세요...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 25),

          // [2] 이모지 선택 시 동그라미 표시 [요구사항 2]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['👍', '👌', '❤️', '💧', '👎'].map((e) => GestureDetector(
              onTap: () => setState(() => vm.selectedEmoji = e),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // 선택된 이모지 주위에 주황색 테두리와 배경 표시
                  color: vm.selectedEmoji == e ? Colors.orange.withOpacity(0.2) : Colors.transparent,
                  border: Border.all(color: vm.selectedEmoji == e ? Colors.orange : Colors.transparent, width: 2),
                ),
                child: Text(e, style: const TextStyle(fontSize: 30)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: vm.pickImage, icon: const Icon(Icons.photo_library, size: 35)),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => vm.stopWalkAndSave(_memoController.text),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                child: const Text("확인", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  // [수정 부분 2] 산책 중 화면 (2~3번 사진 대응): 내 위치 버튼 및 종료 버튼 복구
  Widget _buildWalking(WalkViewModel vm) {
    return Stack(
      children: [
        _buildGoogleMap(vm, interaction: true),

        // 상단 정보 카드 (실시간 시간/거리) [요구사항 5]
        Positioned(
          top: 20, left: 20, right: 20,
          child: WalkInfoCard(seconds: vm.seconds, distanceMeters: vm.distance),
        ),

        // [추가] 사용자의 위치를 중심으로 하는 버튼 복구 [요구사항 4]
        Positioned(
          bottom: 140, // 컨트롤 바 위쪽에 배치
          right: 20,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () => vm.moveToCurrentLocation(),
            child: const Icon(Icons.my_location, color: Color(0xFFFF9800)),
          ),
        ),

        // 하단 컨트롤 패널 (산책 종료 버튼 복구) [요구사항 6]
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: WalkControls(
            isWalking: vm.isWalking,
            isPaused: vm.isPaused,
            distanceMeters: vm.distance,
            seconds: vm.seconds,
            onStart: () {},
            onStop: () => vm.setWalkState(2), // 클릭 시 요약 단계(2)로 이동하며 기록 정지
          ),
        ),
      ],
    );
  }

  Widget _buildMap(WalkViewModel vm) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
          target: vm.currentPosition!, zoom: 16.5), // 1:12,500
      markers: {
        Marker(
          markerId: const MarkerId("pet"),
          position: vm.currentPosition!,
          icon: BitmapDescriptor.defaultMarker, // 여기에 커스텀 마커 적용
        )
      },
      polylines: {
        Polyline(polylineId: const PolylineId("route"),
            points: vm.route,
            color: Colors.orange,
            width: 6),
      },
    );
  }

  // 공통 지도 위젯 (배율 16.5 적용)
  Widget _buildGoogleMap(WalkViewModel vm, {bool interaction = true}) {
    return FutureBuilder<BitmapDescriptor>(
        future: vm.getPetMarkerIcon(vm.selectedPet?['imageUrl']), // 비동기로 마커 생성 호출
        builder: (context, snapshot) {
          return GoogleMap(
            // 1:12,500 배율 적용 (Zoom 16.5)
            initialCameraPosition: CameraPosition(
              target: vm.currentPosition ?? const LatLng(37.5665, 126.9780),
              zoom: 16.5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: interaction,
            polylines: {
              Polyline(
                polylineId: const PolylineId("route"),
                points: vm.route,
                color: const Color(0xFFFF9800), // 주황색 경로
                width: 6,
                jointType: JointType.round,
              ),
            },
            markers: {
              if (vm.currentPosition != null)
                Marker(
                  markerId: const MarkerId("pet_location"),
                  position: vm.currentPosition!,
                  // 스냅샷 데이터(가공된 펫 이미지)가 있으면 적용, 없으면 기본 로딩용 마커
                  icon: snapshot.data ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                ),
            },
            onMapCreated: (controller) => vm.setMapController(controller),
          );
        },
    );
  }

  Widget _buildInitialOverlay(WalkViewModel vm) {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("오늘도 즐거운 산책 해보아용 >.<",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 60),
            GestureDetector(
              onTap: () => vm.startWalk(['pet_dummy_id']),
              child: Container(
                width: 180, height: 180,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF9800), shape: BoxShape.circle),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, size: 50, color: Colors.white),
                    Text("START", style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
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
      builder: (_) =>
          WalkFinishDialog(
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
                        color: isSelected
                            ? Colors.amber.withOpacity(0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.amber)
                            : null,
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
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
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