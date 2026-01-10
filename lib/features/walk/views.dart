import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'viewmodels.dart';
// widgets.dart import 제거함 (파일 내부에 포함)
import 'package:intl/intl.dart'; // [해결] DateFormat 사용을 위해 필수
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp 사용을 위해 추가

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
        key: const ValueKey('walk_appbar'),
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "산책",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
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
          child: RefreshIndicator(
            onRefresh: () async {
              // Pull-to-refresh: 최근 산책 기록 다시 가져오기
              await vm.fetchRecentWalk();
              await vm.fetchMyPets();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // 항상 스크롤 가능하도록 설정
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20), // 상단 여백 추가
              const Text("오늘도 즐거운 산책 해보아용 >.<",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // 여러 반려동물 선택 체크박스
              if (vm.myPets.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "산책할 반려동물 선택",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...vm.myPets.map((pet) {
                        final petId = pet['id'] as String? ?? '';
                        final petName = pet['name'] as String? ?? '강아지';
                        final isPrimary = pet['isPrimary'] == true;
                        final isSelected = vm.isPetSelected(petId);
                        
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) => vm.togglePetSelection(petId),
                          title: Row(
                            children: [
                              Text(
                                petName,
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (isPrimary) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "대표",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          activeColor: const Color(0xFF4CAF50),
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                      if (vm.selectedPetIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "최소 1마리의 반려동물을 선택해주세요.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              // [수정] START 버튼에 발바닥 아이콘 추가
              GestureDetector(
                onTap: () async {
                  // 선택된 반려동물이 없으면 경고
                  if (vm.selectedPetIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("최소 1마리의 반려동물을 선택해주세요."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  // [수정] 시작 시 사용자의 위치를 중심으로 잡아줌 [요구사항 3]
                  try {
                    await vm.startWalk(vm.selectedPetIds.toList());
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("산책 시작 실패: ${e.toString()}"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: vm.recentWalk != null
                    ? _buildRecentWalkCard(vm)
                    : const Center(
                        child: Text("아직 산책 기록이 없어요.\n첫 산책을 시작해보세요!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)),
                      ),
              ),
              const SizedBox(height: 40), // 하단 여백 추가
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 최근 산책 기록 카드 위젯
  Widget _buildRecentWalkCard(WalkViewModel vm) {
    if (vm.recentWalk == null) return const SizedBox.shrink();
    
    final walkData = vm.recentWalk!;
    final endTime = walkData['endTime'] as Timestamp?;
    final distance = walkData['distance'] as double? ?? 0.0;
    final duration = walkData['duration'] as int? ?? 0;
    final emoji = walkData['emoji'] as String? ?? '🐕';
    
    String dateStr = '';
    if (endTime != null) {
      dateStr = DateFormat('yyyy년 MM월 dd일').format(endTime.toDate());
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "최근 산책",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 24)),
            ],
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("거리", "${distance.toStringAsFixed(1)}km"),
              _buildStatItem("시간", "${duration ~/ 60}분 ${duration % 60}초"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // [수정] 요약 화면: 후기 작성하기 버튼 로직 수정
  Widget _buildSummary(WalkViewModel vm) {
    // 시간 포맷팅 (예: 14:30:05)
    // DateFormat을 사용하여 에러 해결
    String startTimeStr = vm.startTime != null
        ? DateFormat('HH:mm:ss').format(vm.startTime!)
        : "--:--";
    String endTimeStr = vm.endTime != null
        ? DateFormat('HH:mm:ss').format(vm.endTime!)
        : "--:--";

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
                Text("시간: $startTimeStr ~ $endTimeStr", style: const TextStyle(color: Colors.grey)),
                Text("거리: ${(vm.distance / 1000).toStringAsFixed(1)}km / 소요: ${vm.seconds ~/ 60}분"),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text("오늘의 산책은 어떠셨나요?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 왼쪽 화살표
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 30),
                onPressed: vm.currentImageIndex > 0
                    ? () => vm.setCurrentImageIndexDecrement()
                    : null,
                color: vm.currentImageIndex > 0 ? Colors.black : Colors.grey.withOpacity(0.3),
              ),

              // [수정 핵심] 사진 유무와 상관없이 동일한 크기를 유지하는 영역
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1, // 1:1 비율(정사각형) 강제 유지
                  child: Container(
                    // [추가] 내부 콘텐츠(아이콘 등)를 중앙에 배치하여 크기 변화 방지
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50, // 빈 영역 배경색 (선택 사항)
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    // Stack을 사용하여 사진과 삭제 버튼(X)을 겹침
                    child: Stack(
                      alignment: Alignment.center, // Stack 내부 요소들도 중앙 정렬
                      children: [
                        // 사진이 없을 때 표시되는 아이콘 (Container 크기를 꽉 채우게 됨)
                        if (vm.reviewImages.isEmpty)
                          const Icon(Icons.image_not_supported, size: 80, color: Colors.grey)

                        // 사진이 있을 때 표시되는 이미지
                        else
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              File(vm.reviewImages[vm.currentImageIndex].path),
                              fit: BoxFit.cover,
                              width: double.infinity, // 부모(Container) 너비에 맞춤
                              height: double.infinity, // 부모(Container) 높이에 맞춤
                            ),
                          ),

                        // 삭제 버튼 (사진이 있을 때만 표시)
                        if (vm.reviewImages.isNotEmpty)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () => vm.removeImage(vm.currentImageIndex),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 오른쪽 화살표
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 30),
                onPressed: vm.currentImageIndex < vm.reviewImages.length - 1
                    ? () => vm.setCurrentImageIndexIncrement()
                    : null,
                color: vm.currentImageIndex < vm.reviewImages.length - 1
                    ? Colors.black
                    : Colors.grey.withOpacity(0.3),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // [요구사항 2] 인디케이터 (제한 없이 모든 사진 표기)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(vm.totalDots, (index) {
              Color dotColor = Colors.white;
              if (vm.reviewImages.isNotEmpty) {
                dotColor = (index == vm.currentImageIndex) ? Colors.black : Colors.grey;
              }
              return Container(
                margin: const EdgeInsets.all(5),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // [요구사항 4] 텍스트 유지 기능을 위한 TextField
          TextField(
            controller: vm.reviewController,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              // 엔터를 누르면 키보드 내리기
              FocusScope.of(context).unfocus();
            },
            decoration: InputDecoration(
              hintText: "산책 후기를 남겨주세요...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 25),

          // 이모지 선택 영역
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: ['👍', '👌', '❤️', '💧', '👎', '🐕', '🐈', '🐶', '😊', '😍', '🥰', '😎', '🤗', '🎉', '✨', '🌟', '💪', '🏃', '🌳', '☀️'].map((e) => GestureDetector(
              onTap: () => vm.setSelectedEmoji(e),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: vm.selectedEmoji == e ? Colors.orange.withOpacity(0.2) : Colors.transparent,
                  border: Border.all(color: vm.selectedEmoji == e ? Colors.orange : Colors.transparent, width: 2),
                ),
                child: Text(e, style: const TextStyle(fontSize: 30)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 30),

          // 하단 액션 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: vm.pickImage,
                  icon: const Icon(Icons.photo_library, size: 35)
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => vm.stopWalkAndSave(vm.reviewController.text),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)
                ),
                child: const Text("확인", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildIndicator(vm), // (인디케이터 로직 생략)
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 인디케이터를 생성하는 별도의 메서드
  Widget _buildIndicator(WalkViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(vm.totalDots, (index) {
        // 사진이 없을 때는 1개의 회색 점, 있을 때는 현재 인덱스에 맞춰 강조
        bool isSelected = vm.reviewImages.isNotEmpty && index == vm.currentImageIndex;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
        );
      }),
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
                "${(distanceMeters / 1000).toStringAsFixed(1)}km, ${(seconds ~/
                    60).toString().padLeft(2, '0')}:${(seconds % 60)
                    .toString()
                    .padLeft(2, '0')}",
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