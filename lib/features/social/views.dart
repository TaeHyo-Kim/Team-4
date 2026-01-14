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

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialViewModel>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socialVM = context.watch<SocialViewModel>();

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "닉네임 검색",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<SocialViewModel>().searchUsers('');
                    FocusScope.of(context).unfocus();
                  },
                )
                    : null,
              ),
              onChanged: (val) {
                context.read<SocialViewModel>().searchUsers(val);
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: socialVM.isLoading
                ? const Center(child: CircularProgressIndicator())
                : socialVM.users.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.person_off, size: 48, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("검색 결과가 없습니다.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: socialVM.users.length,
              itemBuilder: (context, index) {
                final user = socialVM.users[index];
                return _buildUserTile(context, user, socialVM);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user, SocialViewModel vm) {
    final isFollowing = vm.isFollowing(user.uid);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[300],
        backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
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
          backgroundColor: isFollowing ? Colors.grey[200] : const Color(0xFFFF9800),
          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
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
          _isMeFollowingTarget = context.read<SocialViewModel>().isFollowing(widget.user.uid);
          _isLoadingInfo = false;
        });
      }

      // 2. 피드 데이터 로드
      await context.read<ProfileViewModel>().fetchOtherUserWalks(widget.user.uid);
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${userToShow.nickname}님의 프로필",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  backgroundImage: (userToShow.profileImageUrl != null && userToShow.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(userToShow.profileImageUrl!)
                      : null,
                  child: (userToShow.profileImageUrl == null || userToShow.profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 45, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userToShow.nickname,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (userToShow.bio != null && userToShow.bio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(userToShow.bio!,
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                    backgroundColor: isFollowing ? Colors.grey[300] : const Color(0xFFFF9800),
                    foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    ? const Center(child: Text("아직 산책 기록이 없습니다.", style: TextStyle(color: Colors.grey)))
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
                          final photoUrl = walk.photoUrls.isNotEmpty ? walk.photoUrls[0] : null;
                          return GestureDetector(
                            onTap: () => _showWalkDetail(context, walk),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
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
            style: TextStyle(color: Colors.grey[500], fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showWalkDetail(BuildContext context, WalkRecordModel walk) {
    final dateStr = DateFormat('yyyy년 MM월 d일').format(walk.startTime.toDate());
    final timeStr = DateFormat('HH:mm').format(walk.startTime.toDate());

    // 시, 분, 초 계산
    final hours = walk.duration ~/ 3600;
    final minutes = (walk.duration % 3600) ~/ 60;
    final seconds = walk.duration % 60;

    final durationText = hours > 0 
        ? "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    
    final durationUnit = hours > 0 ? "시:분:초" : "분:초";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
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
                          Text(dateStr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                          Text("$timeStr 산책 완료 ✨", style: const TextStyle(fontSize: 14, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.grey)),
                    ],
                  ),
                ),

                // 이미지
                if (walk.photoUrls.isNotEmpty)
                  Container(
                    height: 280,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: PageView.builder(
                        itemCount: walk.photoUrls.length,
                        itemBuilder: (context, index) => Image.network(walk.photoUrls[index], fit: BoxFit.cover),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: const Color(0xFFFFF9C4).withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.pets, size: 60, color: Color(0xFFFFC107)),
                  ),

                // 함께한 펫 (태그)
                // Note: OtherUserProfileView에서는 상대방의 펫 정보 리스트를 직접 가지고 있지 않으므로 
                // 간단하게 아이콘과 텍스트로 대체하거나 추후 보강 가능
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
                  child: Wrap(
                    spacing: 8,
                    children: walk.petIds.map((id) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.pets, size: 14, color: Color(0xFF2E7D32)),
                          SizedBox(width: 6),
                          Text("함께한 친구", style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
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
                    border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLuxStatItem(Icons.straighten_rounded, "${walk.distance.toStringAsFixed(2)}", "km", const Color(0xFF4CAF50)),
                      _buildLuxStatItem(Icons.access_time_rounded, durationText, durationUnit, const Color(0xFFFF9800)),
                      _buildLuxStatItem(Icons.local_fire_department_rounded, "${walk.calories.toInt()}", "kcal", const Color(0xFFE53935)),
                    ],
                  ),
                ),

                // 후기
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(walk.emoji.isNotEmpty ? walk.emoji : "🐕", style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          const Text("기록 한 줄", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF34495E))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        walk.memo.isNotEmpty ? walk.memo : "산책 기록이 없습니다.",
                        style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF5D6D7E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxStatItem(IconData icon, String value, String unit, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showBlockDialog(BuildContext context, SocialViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("사용자 차단"),
        content: Text("${widget.user.nickname}님을 차단하시겠습니까?\n차단하면 검색 결과에 나타나지 않으며 팔로우가 해제됩니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
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
        title: const Text("차단된 계정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: socialVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : socialVM.blockedUserList.isEmpty
              ? const Center(child: Text("차단된 계정이 없습니다.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: socialVM.blockedUserList.length,
                  itemBuilder: (context, index) {
                    final user = socialVM.blockedUserList[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(user.profileImageUrl!)
                            : null,
                        child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
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
