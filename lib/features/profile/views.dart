import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../auth/viewmodels.dart';
import '../auth/views.dart'; 
import '../pet/views.dart'; 
import '../social/views.dart';
import '../social/viewmodels.dart';
import 'viewmodels.dart';

// [A] 프로필 조회 화면 (디자인 복구 및 레이아웃 최적화)
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.userModel;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("프로필", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. [고정] 프로필 상단 정보 (이미지, 이름, 소개, 팔로워/팔로잉 + 우측 편집 버튼)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 30, 10, 20), // 오버플로우 방지를 위한 여백 최적화
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 42, 
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 42, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12), 
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user?.nickname ?? "익명 유저", 
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(user?.bio ?? "좋은 하루 되세요", 
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      // 통계 정보 위젯 (공통 컴포넌트 사용)
                      UserStatsRow(
                        userId: user?.uid ?? '',
                        postCount: user?.stats.postCount ?? 0,
                        followingCount: user?.stats.followingCount ?? 0,
                        followerCount: user?.stats.followerCount ?? 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5), 
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditView())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("프로필 편집", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(thickness: 1, color: Colors.black12, height: 1),

          // 2. [스크롤] 반려동물 목록 및 피드
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                  child: PetScreen(),
                ),
                const SizedBox(height: 80),
                const Center(
                  child: Text(
                    "아직 산책 기록이 없습니다.",
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// [B] 프로필 수정 화면
class ProfileEditView extends StatefulWidget {
  const ProfileEditView({super.key});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final _nickCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().userModel;
    _nickCtrl.text = user?.nickname ?? "";
    _bioCtrl.text = user?.bio ?? "";
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final user = context.watch<AuthViewModel>().userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text("프로필 수정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!) as ImageProvider
                        : (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(user.profileImageUrl!) as ImageProvider
                            : null,
                    child: (_imageFile == null && (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6), 
                      decoration: const BoxDecoration(color: Color(0xFF3498DB), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 22, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildInput("닉네임", _nickCtrl),
            _buildInput("한줄소개", _bioCtrl),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: vm.isLoading ? null : () async {
                  await vm.updateProfile(nickname: _nickCtrl.text.trim(), bio: _bioCtrl.text.trim(), imageFile: _imageFile);
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB)),
                child: vm.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("수정 완료", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 20),
      ],
    );
  }
}

// 통계 정보 행 위젯 (재사용 가능 - 공통 컴포넌트)
class UserStatsRow extends StatelessWidget {
  final String userId;
  final int postCount;
  final int followingCount;
  final int followerCount;

  const UserStatsRow({
    required this.userId,
    required this.postCount,
    required this.followingCount,
    required this.followerCount,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            "게시물 $postCount",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (userId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowListScreen(
                      userId: userId,
                      isFollowingList: true,
                    ),
                  ),
                );
              }
            },
            child: Text(
              "팔로우 $followingCount",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (userId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowListScreen(
                      userId: userId,
                      isFollowingList: false,
                    ),
                  ),
                );
              }
            },
            child: Text(
              "팔로워 $followerCount",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// [C] 팔로워/팔로잉 목록 화면
class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool isFollowingList; // true: 팔로잉 목록, false: 팔로워 목록

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.isFollowingList,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileVM = context.read<ProfileViewModel>();
      final socialVM = context.read<SocialViewModel>();
      
      // SocialViewModel의 팔로우 상태도 업데이트
      socialVM.fetchUsers();
      
      if (widget.isFollowingList) {
        profileVM.fetchFollowingUsers(widget.userId);
      } else {
        profileVM.fetchFollowerUsers(widget.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileVM = context.watch<ProfileViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final socialVM = context.watch<SocialViewModel>();
    final myUid = authVM.userModel?.uid;
    
    final users = widget.isFollowingList 
        ? profileVM.followingUsers 
        : profileVM.followerUsers;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isFollowingList ? "팔로잉" : "팔로워",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: profileVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isFollowingList ? Icons.person_outline : Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isFollowingList 
                            ? "팔로잉한 사용자가 없습니다." 
                            : "팔로워가 없습니다.",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isMe = user.uid == myUid;
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: user.profileImageUrl != null && 
                                user.profileImageUrl!.isNotEmpty
                            ? NetworkImage(user.profileImageUrl!)
                            : null,
                        child: (user.profileImageUrl == null || 
                                user.profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        user.nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        user.bio ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: isMe
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "나",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () async {
                                try {
                                  await socialVM.toggleFollow(user.uid);
                                  // 팔로우 상태 변경 후 목록 새로고침
                                  final profileVM = context.read<ProfileViewModel>();
                                  if (widget.isFollowingList) {
                                    await profileVM.fetchFollowingUsers(widget.userId);
                                  } else {
                                    await profileVM.fetchFollowerUsers(widget.userId);
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("작업에 실패했습니다."),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: socialVM.isFollowing(user.uid)
                                    ? Colors.grey[200]
                                    : Colors.amber,
                                foregroundColor: socialVM.isFollowing(user.uid)
                                    ? Colors.black87
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                socialVM.isFollowing(user.uid) ? "팔로잉" : "팔로우",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                      onTap: isMe
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OtherUserProfileView(user: user),
                                ),
                              );
                            },
                    );
                  },
                ),
    );
  }
}
