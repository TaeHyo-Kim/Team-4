import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'viewmodels.dart';
import '../auth/models.dart';
import '../profile/views.dart';
import '../profile/viewmodels.dart';
import '../walk/models.dart';
import '../pet/viewmodels.dart';
import '../auth/viewmodels.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode(); // 검색창 포커스 감지용
  GoogleMapController? _mapController;
  bool _isFocused = false;
  UserModel? _selectedUser; // 마커 클릭 시 선택된 유저 정보 저장
  Timer? _mapInactivityTimer;      // 지도 비활성 타이머 관련 에러 해결
  bool _isUserInteracting = false; // 사용자 상호작용 감지 에러 해결
  bool _isSearchBarFocused = false; // 87번 라인 _isSearchBarFocused 에러 해결

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialViewModel>().fetchUsers();
    });
  }

  // [추가] image_6b6b84.png 34번 라인에서 참조하는 메서드 정의
  void _onSearchFocusChange() {
    setState(() {
      _isSearchBarFocused = _searchFocus.hasFocus;
    });
  }

  // [추가] image_6b6b84.png 46~63번 라인 관련 상호작용 로직 (에러 해결용)
  void _onInteractionStarted() {
    setState(() {
      _isUserInteracting = true;
      _mapInactivityTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapInactivityTimer?.cancel(); // [추가] 타이머 해제
    super.dispose();
  }

// [추가] 조작 종료 후 5초 대기 후 중심 이동
  void _onInteractionEnded() {
    _mapInactivityTimer?.cancel();_mapInactivityTimer = Timer(const Duration(seconds: 5), () async {
      if (mounted && !_isUserInteracting) {
        setState(() {
          _isUserInteracting = false;
        });
        // [추가] 요구사항에 따라 내 위치로 카메라 이동
        await _moveToMyLocation();
      }
    });
  }

// [추가] 지도를 내 현재 위치로 이동
  Future<void> _moveToMyLocation() async {
    if (_mapController == null) return;
    try {
      Position pos = await Geolocator.getCurrentPosition();
      await _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude))
      );
    } catch (e) {
      debugPrint("지도 중심 이동 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {

    bool isListMode = _isSearchBarFocused || _searchCtrl.text.isNotEmpty;
    final socialVM = context.watch<SocialViewModel>();
    // 검색 중이거나 검색창에 포커스가 있는 경우 리스트 모드
    bool showListMode = _isFocused || _searchCtrl.text.isNotEmpty;
    bool showMap = !_isSearchBarFocused && _searchCtrl.text.isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "검색",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 검색창 영역
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: "닉네임 검색",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                suffixIcon: _searchCtrl.text.isNotEmpty || _isFocused
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchFocus.unfocus();
                    context.read<SocialViewModel>().searchUsers('');
                  },
                )
                    : null,
              ),
              onChanged: (val) =>
                  context.read<SocialViewModel>().searchUsers(val),
            ),
          ),
          Expanded(
            child: isListMode
                ? _buildUserList(socialVM)
                : Listener(
              onPointerDown: (_) => _onInteractionStarted(),
              onPointerUp: (_) => _onInteractionEnded(),
              child: _buildMapView(socialVM),
            ),
          ),
        ],
      ),
    );
  }

  // 기능 1: 지도 뷰 (기본 상태)
  Widget _buildMapView(SocialViewModel vm) {
    return FutureBuilder<Position>(
      future: Geolocator.getCurrentPosition(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

       final myLatLng = LatLng(snapshot.data!.latitude, snapshot.data!.longitude);

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: myLatLng, zoom: 15),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false, // 커스텀 로직이 있으므로 버튼은 숨김
              circles: {
                Circle(
                  circleId: const CircleId("nearby_range"),
                  center: myLatLng,
                  radius: 1000, // 1km
                  fillColor: Colors.blue.withOpacity(0.05),
                  strokeColor: Colors.blue.withOpacity(0.2),
                  strokeWidth: 1,
                ),
              },
              // [수정] 커스텀 마커 적용 및 클릭 이벤트
              markers: vm.nearbyUsers.map((user) {
                final pos = user.position as GeoPoint?; // 명시적 캐스팅
                return Marker(
                  markerId: MarkerId(user.uid),
                  position: LatLng(pos?.latitude ?? 0.0, pos?.longitude ?? 0.0),
                  onTap: () {
                    _onInteractionStarted(); // 마커 클릭 시 자동 이동 일시 중지
                    setState(() => _selectedUser = user);
                  },
                );
              }).toSet(),
              onTap: (_) => setState(() => _selectedUser = null), // 빈 화면 터치 시 정보창 닫기
            ),

            // [추가] 마커 클릭 시 나타나는 정보 상자 (image_6af28c.png 스타일)
            if (_selectedUser != null)
              Positioned(
                bottom: 30, left: 20, right: 20,
                child: _buildUserMiniCard(_selectedUser!),
              ),
          ],
        );
      },
    );
  }

  // [추가] 유저 정보 미니 카드 위젯 (이미지 우측 닉네임/소개/버튼 구조)
  Widget _buildUserMiniCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800), // 주황색 배경
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                ? NetworkImage(user.profileImageUrl!) : null,
            child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.nickname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(user.bio ?? "좋은 하루!", style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileView(user: user))),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text("프로필", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 기능 2: 사용자 리스트 (검색창 클릭/입력 시)
  Widget _buildUserList(SocialViewModel vm) {
    if (vm.isLoading) return const Center(child: CircularProgressIndicator());
    if (vm.users.isEmpty) {
      return Center(child: Text(_searchCtrl.text.isEmpty ? "팔로우한 사용자가 없습니다." : "검색 결과가 없습니다."));
    }
    return ListView.builder(
      itemCount: vm.users.length,
      itemBuilder: (context, index) => _buildUserTile(context, vm.users[index], vm),
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user,
      SocialViewModel vm) {
    final isFollowing = vm.isFollowing(user.uid);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[300],
        backgroundImage: user.profileImageUrl != null &&
            user.profileImageUrl!.isNotEmpty
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(
        user.nickname,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        user.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: ElevatedButton(
        onPressed: () async {
          try {
            await context.read<SocialViewModel>().toggleFollow(user.uid);
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("작업에 실패했습니다.")),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.grey[200] : const Color(
              0xFFFF9800),
          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          isFollowing ? "팔로잉" : "팔로우",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherUserProfileView(user: user),
          ),
        );
      },
    );
  }
}

class OtherUserProfileView extends StatefulWidget {
  final UserModel user;

  const OtherUserProfileView({super.key, required this.user});

  @override
  State<OtherUserProfileView> createState() => _OtherUserProfileViewState();
}

class _OtherUserProfileViewState extends State<OtherUserProfileView> {
  UserModel? _latestUser;
  bool _isMeFollowingTarget = false;
  bool _isTargetFollowingMe = false;
  bool _isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoadingInfo = true);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    try {
      // 1. 최신 유저 정보 및 팔로우 관계 확인
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(
          widget.user.uid).get();
      final followingMeMeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('following')
          .doc(myUid)
          .get();

      if (mounted) {
        setState(() {
          if (userDoc.exists) _latestUser = UserModel.fromDocument(userDoc);
          _isTargetFollowingMe = followingMeMeDoc.exists;
          _isMeFollowingTarget =
              context.read<SocialViewModel>().isFollowing(widget.user.uid);
          _isLoadingInfo = false;
        });
      }

      // 2. 피드 데이터 로드
      await context.read<ProfileViewModel>().fetchOtherUserWalks(
          widget.user.uid);
    } catch (e) {
      debugPrint("정보 로드 실패: $e");
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  bool _canSeeFeed() {
    if (_latestUser == null) return false;
    final visibility = _latestUser!.visibility;

    if (visibility == 'all') return true;
    if (visibility == 'friends') {
      // 친구 관계: 서로 팔로우
      return _isMeFollowingTarget && _isTargetFollowingMe;
    }
    return false; // visibility == 'none'
  }

  @override
  Widget build(BuildContext context) {
    final socialVM = context.watch<SocialViewModel>();
    final profileVM = context.watch<ProfileViewModel>();
    final userToShow = _latestUser ?? widget.user;
    final isFollowing = socialVM.isFollowing(userToShow.uid);
    // [수정] 검색창에 포커스가 있거나 검색어가 입력된 경우 리스트 모드 활성화

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${userToShow.nickname}님의 프로필",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.block),
            onPressed: () => _showBlockDialog(context, socialVM),
            tooltip: "차단하기",
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 프로필 영역
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 35, 15, 25),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (userToShow.profileImageUrl != null &&
                      userToShow.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(userToShow.profileImageUrl!)
                      : null,
                  child: (userToShow.profileImageUrl == null ||
                      userToShow.profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 45, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userToShow.nickname,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      if (userToShow.bio != null &&
                          userToShow.bio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(userToShow.bio!,
                            style: const TextStyle(color: Colors.grey,
                                fontSize: 13)),
                      ],
                      const SizedBox(height: 12),
                      UserStatsRow(
                        userId: userToShow.uid,
                        postCount: profileVM.otherUserWalkRecords.length,
                        followingCount: userToShow.stats.followingCount,
                        followerCount: userToShow.stats.followerCount,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await socialVM.toggleFollow(userToShow.uid);
                    _refreshAll();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing
                        ? Colors.grey[300]
                        : const Color(0xFFFF9800),
                    foregroundColor: isFollowing ? Colors.black87 : Colors
                        .white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isFollowing ? "팔로잉" : "팔로우",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 피드 영역 (공개 범위에 따른 처리)
          Expanded(
            child: _isLoadingInfo
                ? const Center(child: CircularProgressIndicator())
                : !_canSeeFeed()
                ? _buildLockedScreen(userToShow.visibility)
                : profileVM.isLoading
                ? const Center(child: CircularProgressIndicator())
                : profileVM.otherUserWalkRecords.isEmpty
                ? const Center(child: Text(
                "아직 산책 기록이 없습니다.", style: TextStyle(color: Colors.grey)))
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: profileVM.otherUserWalkRecords.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final walk = profileVM.otherUserWalkRecords[index];
                final photoUrl = walk.photoUrls.isNotEmpty
                    ? walk.photoUrls[0]
                    : null;
                return GestureDetector(
                  onTap: () => _showWalkDetail(context, walk),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 5)
                      ],
                    ),
                    child: photoUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(photoUrl, fit: BoxFit.cover),
                    )
                        : const Icon(Icons.directions_walk, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedScreen(String visibility) {
    String message = "비공개 프로필입니다.";
    IconData icon = Icons.lock_outline;

    if (visibility == 'friends') {
      message = "서로 팔로우한 친구에게만\n공개된 피드입니다.";
      icon = Icons.people_outline;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showWalkDetail(BuildContext context, WalkRecordModel walk) {
    final dateStr = DateFormat('yyyy년 MM월 d일').format(walk.startTime.toDate());
    final timeStr = DateFormat('HH:mm').format(walk.startTime.toDate());
    final timeEnd = DateFormat('HH:mm').format(walk.endTime.toDate());

    // 시, 분, 초 계산
    final hours = walk.duration ~/ 3600;
    final minutes = (walk.duration % 3600) ~/ 60;
    final seconds = walk.duration % 60;

    final durationText = hours > 0
        ? "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(
        2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(
        2, '0')}";

    final durationUnit = hours > 0 ? "시:분:초" : "분:초";

    // 내 닉네임 가져오기 (알림용)
    final myProfile = context.read<AuthViewModel>().userModel;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // 다이얼로그 내부에서 사진 인덱스 상태를 관리하기 위한 변수
        int currentImageIndex = 0;

        // StatefulBuilder를 사용하여 다이얼로그 내부의 상태(인디케이터)만 갱신합니다.
        return StatefulBuilder(
            builder: (context, setStateInsideDialog) {
              return Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 헤더
                          Container(
                            padding: const EdgeInsets.fromLTRB(25, 20, 15, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dateStr, style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2C3E50))),
                                    Text("$timeStr ~ $timeEnd 산책 완료 ✨",
                                        style: const TextStyle(fontSize: 14,
                                            color: Color(0xFF4CAF50),
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                IconButton(onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(
                                        Icons.close, color: Colors.grey)),
                              ],
                            ),
                          ),

                          // 이미지
                          if (walk.photoUrls.isNotEmpty)
                          // [수정] 컬럼으로 감싸서 인디케이터를 아래에 배치
                            Column(
                              children: [
                                Container(
                                  height: 280,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: PageView.builder(
                                      itemCount: walk.photoUrls.length,
                                      // [추가] 페이지 변경 시 인덱스 업데이트
                                      onPageChanged: (index) {
                                        setStateInsideDialog(() {
                                          currentImageIndex = index;
                                        });
                                      },
                                      itemBuilder: (context, index) =>
                                          Image.network(walk.photoUrls[index],
                                              fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // [추가] 기능 2: 인디케이터 표시
                                _buildIndicator(
                                    walk.photoUrls.length, currentImageIndex),
                              ],
                            )
                          else
                            Container(
                              height: 180,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9C4).withOpacity(
                                      0.5),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.pets, size: 60,
                                  color: Color(0xFFFFC107)),
                            ),

                          // 함께한 펫 (태그)
                          // Note: OtherUserProfileView에서는 상대방의 펫 정보 리스트를 직접 가지고 있지 않으므로
                          // 간단하게 아이콘과 텍스트로 대체하거나 추후 보강 가능
                          if (walk.petIds.isNotEmpty)
                          // 인디케이터가 생겨서 상단 패딩 약간 조정 (15 -> 10)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                              child: Wrap(
                                spacing: 8,
                                children: walk.petIds.map((id) =>
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(
                                              15)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.pets, size: 14,
                                              color: Color(0xFF2E7D32)),
                                          SizedBox(width: 6),
                                          Text("함께한 친구", style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF2E7D32),
                                              fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    )).toList(),
                              ),
                            ),

                          // 데이터 카드
                          Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFFFD54F).withOpacity(
                                      0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildLuxStatItem(Icons.straighten_rounded,
                                    "${walk.distance.toStringAsFixed(2)}", "km",
                                    const Color(0xFF4CAF50)),
                                _buildLuxStatItem(
                                    Icons.access_time_rounded, durationText,
                                    durationUnit, const Color(0xFFFF9800)),
                                _buildLuxStatItem(
                                    Icons.local_fire_department_rounded,
                                    "${walk.calories.toInt()}", "kcal",
                                    const Color(0xFFE53935)),
                              ],
                            ),
                          ),

                          // 기록 한 줄 + 좋아요 버튼 영역
                          Padding(
                            padding: const EdgeInsets.fromLTRB(25, 10, 25, 25),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(walk.emoji.isNotEmpty ? walk.emoji : "🐕", style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 10),
                                    const Text("기록 한 줄", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF34495E))),
                                    const Spacer(),

                                    // 좋아요 버튼 (StreamBuilder로 실시간 상태 확인)
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('walks')
                                          .doc(walk.id)
                                          .collection('likes')
                                          .doc(myUid)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final isLiked = snapshot.hasData &&
                                            snapshot.data!.exists;
                                        return IconButton(
                                          onPressed: () async {
                                            await context.read<
                                                SocialViewModel>().toggleLike(
                                              walkId: walk.id ?? "",
                                              ownerId: walk.userId,
                                              myNickname: myProfile?.nickname ??
                                                  "익명",
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger
                                                  .of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(isLiked
                                                      ? "좋아요를 취소했습니다."
                                                      : "이 기록을 좋아합니다! ❤️"),
                                                  duration: const Duration(
                                                      seconds: 1),
                                                ),
                                              );
                                            }
                                          },
                                          icon: Icon(
                                            isLiked ? Icons.favorite : Icons
                                                .favorite_border,
                                            color: isLiked ? Colors.red : Colors
                                                .grey,
                                            size: 28,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  walk.memo.isNotEmpty
                                      ? walk.memo
                                      : "산책 기록이 없습니다.",
                                  style: const TextStyle(fontSize: 15,
                                      height: 1.6,
                                      color: Color(0xFF5D6D7E)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ));
            }
        );
      },
    );
  }

  // [추가] 기능 2: 인디케이터 빌드 메서드 (제공해주신 코드 수정)
  Widget _buildIndicator(int totalCount, int currentIndex) {
    // 사진이 1장 이하일 때는 인디케이터를 표시하지 않음
    if (totalCount <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        bool isSelected = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isSelected ? 16 : 8,
          // 선택되면 약간 넓어지는 효과
          height: 8,
          decoration: BoxDecoration(
            // 앱 테마색(초록색) 적용, 선택 안된건 회색
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4), // 동그라미 대신 둥근 사각형 형태로 변경 (취향에 따라 BoxShape.circle로 변경 가능)
          ),
        );
      }),
    );
  }

  Widget _buildLuxStatItem(IconData icon, String value, String unit,
      Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50))),
        Text(unit, style: const TextStyle(
            fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showBlockDialog(BuildContext context, SocialViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text("사용자 차단"),
            content: Text("${widget.user
                .nickname}님을 차단하시겠습니까?\n차단하면 검색 결과에 나타나지 않으며 팔로우가 해제됩니다."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
              TextButton(
                onPressed: () async {
                  await vm.toggleBlock(widget.user.uid);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("차단되었습니다.")),
                    );
                  }
                },
                child: const Text("차단", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialViewModel>().fetchBlockedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final socialVM = context.watch<SocialViewModel>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("차단된 계정",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: socialVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : socialVM.blockedUserList.isEmpty
          ? const Center(
          child: Text("차단된 계정이 없습니다.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        itemCount: socialVM.blockedUserList.length,
        itemBuilder: (context, index) {
          final user = socialVM.blockedUserList[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: (user.profileImageUrl != null &&
                  user.profileImageUrl!.isNotEmpty)
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: (user.profileImageUrl == null ||
                  user.profileImageUrl!.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(user.nickname,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: OutlinedButton(
              onPressed: () => socialVM.unblockUser(user.uid),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("차단 해제"),
            ),
          );
        },
      ),
    );
  }
}
