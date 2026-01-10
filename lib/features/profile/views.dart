import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../auth/viewmodels.dart';
import '../auth/views.dart'; 
import '../pet/viewmodels.dart';
import '../social/viewmodels.dart';
import '../social/views.dart';
import '../walk/models.dart';
import '../../core/permission_service.dart';
import 'viewmodels.dart';

// [A] 프로필 조회 화면 (반려동물별 필터링 기능 추가)
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final FocusNode _focusNode = FocusNode();
  String? _selectedPetId; // 필터링을 위해 선택된 반려동물 ID

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _refreshData();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await Future.wait([
      context.read<ProfileViewModel>().fetchMyWalkRecords(),
      context.read<PetViewModel>().fetchMyPets(),
      context.read<AuthViewModel>().fetchUserProfile(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final profileVM = context.watch<ProfileViewModel>();
    final petVM = context.watch<PetViewModel>();
    final user = authVM.userModel;

    // 선택된 반려동물에 따라 산책 기록 필터링
    final filteredWalks = _selectedPetId == null 
        ? profileVM.walkRecords 
        : profileVM.walkRecords.where((walk) => walk.petIds.contains(_selectedPetId)).toList();

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
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Column(
          children: [
            // 1. [고정] 프로필 상단 정보
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 35, 10, 25),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 38, 
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                        ? NetworkImage(user.profileImageUrl!) : null,
                    child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 38, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user?.nickname ?? "익명 유저", 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(user?.bio ?? "좋은 하루 되세요", 
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        UserStatsRow(
                          userId: user?.uid ?? "",
                          postCount: profileVM.walkRecords.length,
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
                    child: const Text("프로필 편집", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1, color: Colors.black12, height: 1),

            // 2. [고정] 반려동물 목록 (클릭 시 필터링)
            if (petVM.pets.isNotEmpty) ...[
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: petVM.pets.length,
                  itemBuilder: (context, index) {
                    final pet = petVM.pets[index];
                    final isSelected = _selectedPetId == pet.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPetId = null; // 이미 선택된 경우 해제
                          } else {
                            _selectedPetId = pet.id; // 새로운 펫 선택
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 25,
                                backgroundImage: pet.imageUrl.isNotEmpty ? NetworkImage(pet.imageUrl) : null,
                                child: pet.imageUrl.isEmpty ? const Icon(Icons.pets, size: 15) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pet.name, 
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF4CAF50) : Colors.black,
                              )
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(thickness: 1, color: Colors.black12, height: 1),
            ],

            // 3. [스크롤 영역] 필터링된 산책 기록 피드
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFF4CAF50),
                child: profileVM.isLoading && profileVM.walkRecords.isEmpty
                  ? const Center(child: CircularProgressIndicator()) 
                  : ListView(
                      padding: EdgeInsets.zero,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (filteredWalks.isEmpty)
                          Container(
                            height: 300, 
                            alignment: Alignment.center,
                            child: Text(
                              _selectedPetId == null 
                                  ? "아직 산책 기록이 없습니다." 
                                  : "해당 반려동물과 함께한 기록이 없습니다.",
                              style: const TextStyle(color: Colors.black38, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredWalks.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
                              ),
                              itemBuilder: (context, index) {
                                final walk = filteredWalks[index];
                                final photoUrl = walk.photoUrls.isNotEmpty ? walk.photoUrls[0] : null;
                                return GestureDetector(
                                  onTap: () => _showWalkDetail(context, walk),
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                    child: photoUrl != null 
                                      ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(photoUrl, fit: BoxFit.cover))
                                      : const Icon(Icons.directions_walk, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalkDetail(BuildContext context, WalkRecordModel walk) {
    final startDate = walk.startTime.toDate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("산책 기록 - ${startDate.year}.${startDate.month}.${startDate.day}"),
        content: Text("거리: ${walk.distance.toStringAsFixed(2)} km\n시간: ${(walk.duration ~/ 60)}분\n후기: ${walk.memo}"),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기"))],
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
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().userModel;
    _nickCtrl.text = user?.nickname ?? "";
    _bioCtrl.text = user?.bio ?? "";
  }

  Future<void> _pickImage() async {
    final photosStatus = await _permissionService.getPhotosPermissionStatus();
    if (photosStatus != ph.PermissionStatus.granted) {
      final granted = await _permissionService.requestPhotosPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 권한이 필요합니다.')));
        return;
      }
    }
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
      const SizedBox(height: 20),
    ]);
  }
}

// 통계 정보 행 위젯
class UserStatsRow extends StatelessWidget {
  final String userId;
  final int postCount;
  final int followingCount;
  final int followerCount;

  const UserStatsRow({
    super.key,
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
          Text("게시물 $postCount", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => userId.isNotEmpty ? Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(userId: userId, isFollowingList: true))) : null,
            child: Text("팔로우 $followingCount", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => userId.isNotEmpty ? Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(userId: userId, isFollowingList: false))) : null,
            child: Text("팔로워 $followerCount", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// [C] 팔로워/팔로잉 목록 화면
class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool isFollowingList;
  const FollowListScreen({super.key, required this.userId, required this.isFollowingList});
  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileVM = context.read<ProfileViewModel>();
      context.read<SocialViewModel>().fetchUsers();
      widget.isFollowingList ? profileVM.fetchFollowingUsers(widget.userId) : profileVM.fetchFollowerUsers(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileVM = context.watch<ProfileViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final socialVM = context.watch<SocialViewModel>();
    final myUid = authVM.userModel?.uid;
    final users = widget.isFollowingList ? profileVM.followingUsers : profileVM.followerUsers;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isFollowingList ? "팔로잉" : "팔로워", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50), elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: profileVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(widget.isFollowingList ? Icons.person_outline : Icons.people_outline, size: 64, color: Colors.grey[400]), const SizedBox(height: 16), Text(widget.isFollowingList ? "팔로잉한 사용자가 없습니다." : "팔로워가 없습니다.", style: TextStyle(color: Colors.grey[600], fontSize: 16))]))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isMe = user.uid == myUid;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(radius: 28, backgroundColor: Colors.grey[300], backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) ? NetworkImage(user.profileImageUrl!) : null, child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.white) : null),
                      title: Text(user.nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(user.bio ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                      trailing: isMe ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)), child: const Text("나", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))) : ElevatedButton(onPressed: () async { await socialVM.toggleFollow(user.uid); final profileVM = context.read<ProfileViewModel>(); widget.isFollowingList ? await profileVM.fetchFollowingUsers(widget.userId) : await profileVM.fetchFollowerUsers(widget.userId); }, style: ElevatedButton.styleFrom(backgroundColor: socialVM.isFollowing(user.uid) ? Colors.grey[200] : Colors.amber, foregroundColor: socialVM.isFollowing(user.uid) ? Colors.black87 : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), child: Text(socialVM.isFollowing(user.uid) ? "팔로잉" : "팔로우", style: const TextStyle(fontWeight: FontWeight.bold))),
                      onTap: isMe ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileView(user: user))),
                    );
                  },
                ),
    );
  }
}
