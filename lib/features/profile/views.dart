import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:intl/intl.dart';
import '../auth/viewmodels.dart';
import '../auth/views.dart'; 
import '../pet/viewmodels.dart';
import '../social/viewmodels.dart';
import '../social/views.dart';
import '../walk/models.dart';
import '../../core/permission_service.dart';
import 'viewmodels.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final FocusNode _focusNode = FocusNode();
  String? _selectedPetId;

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

    final filteredWalks = _selectedPetId == null 
        ? profileVM.walkRecords 
        : profileVM.walkRecords.where((walk) => walk.petIds.contains(_selectedPetId)).toList();

    return Scaffold(
      backgroundColor: Colors.white, // 배경을 하얀색으로 변경
      appBar: AppBar(
        title: const Text("내 프로필", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
        onFocusChange: (hasFocus) {
          if (hasFocus) _refreshData();
        },
        child: Column(
          children: [
            // 1. 유저 프로필 상단
            Container(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white,
                      backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                          ? NetworkImage(user.profileImageUrl!) : null,
                      child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 45, color: Color(0xFF4CAF50)) : null,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nickname ?? "익명 유저", 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(user?.bio ?? "행복한 반려생활 중 🐾", 
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                        const SizedBox(height: 12),
                        UserStatsRow(
                          userId: user?.uid ?? "",
                          postCount: profileVM.walkRecords.length,
                          followingCount: user?.stats.followingCount ?? 0,
                          followerCount: user?.stats.followerCount ?? 0,
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 프로필 편집 버튼
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditView())),
                      icon: const Icon(Icons.edit_note, size: 20),
                      label: const Text("프로필 편집", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800), 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. 반려동물 목록
            if (petVM.pets.isNotEmpty) ...[
              Container(
                height: 110,
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: petVM.pets.length,
                  itemBuilder: (context, index) {
                    final pet = petVM.pets[index];
                    final isSelected = _selectedPetId == pet.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPetId = isSelected ? null : pet.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 18),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isSelected ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFFFFEB3B)]) : null,
                                border: isSelected ? null : Border.all(color: Colors.grey[300]!, width: 1.5),
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white,
                                backgroundImage: pet.imageUrl.isNotEmpty ? NetworkImage(pet.imageUrl) : null,
                                child: pet.imageUrl.isEmpty ? const Icon(Icons.pets, size: 20, color: Colors.grey) : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(pet.name, style: TextStyle(
                              fontSize: 12, 
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF4CAF50) : Colors.black87,
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(thickness: 1, height: 1),
              ),
            ],

            // 4. 산책 기록 피드
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFF4CAF50),
                child: profileVM.isLoading && profileVM.walkRecords.isEmpty
                  ? const Center(child: CircularProgressIndicator()) 
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredWalks.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final walk = filteredWalks[index];
                        final photoUrl = walk.photoUrls.isNotEmpty ? walk.photoUrls[0] : null;
                        return GestureDetector(
                          onTap: () => _showWalkDetail(context, walk),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                              border: Border.all(color: Colors.grey[100]!),
                            ),
                            child: photoUrl != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(photoUrl, fit: BoxFit.cover))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions_walk, color: const Color(0xFF4CAF50).withOpacity(0.5), size: 30),
                                    const SizedBox(height: 4),
                                    Text("${walk.distance.toStringAsFixed(1)}km", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                          ),
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalkDetail(BuildContext context, WalkRecordModel walk) {
    final petVM = context.read<PetViewModel>();
    final walkPets = petVM.pets.where((p) => walk.petIds.contains(p.id)).toList();
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

                if (walkPets.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
                    child: Wrap(
                      spacing: 8,
                      children: walkPets.map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 10, backgroundImage: p.imageUrl.isNotEmpty ? NetworkImage(p.imageUrl) : null, child: p.imageUrl.isEmpty ? const Icon(Icons.pets, size: 8) : null),
                            const SizedBox(width: 6),
                            Text(p.name, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),

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
                        walk.memo.isNotEmpty ? walk.memo : "오늘도 즐거운 산책이었어요!",
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
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class UserStatsRow extends StatelessWidget {
  final String userId;
  final int postCount;
  final int followingCount;
  final int followerCount;
  final Color textColor;

  const UserStatsRow({
    super.key,
    required this.userId,
    required this.postCount,
    required this.followingCount,
    required this.followerCount,
    this.textColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildItem("기록", postCount),
        _buildDivider(),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(userId: userId, isFollowingList: true))),
          child: _buildItem("팔로우", followingCount),
        ),
        _buildDivider(),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(userId: userId, isFollowingList: false))),
          child: _buildItem("팔로워", followerCount),
        ),
      ],
    );
  }

  Widget _buildItem(String label, int value) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8))),
        const SizedBox(width: 5),
        Text("$value", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 12, width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: textColor.withOpacity(0.3),
    );
  }
}

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
      if (!granted) return;
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
        child: Column(children: [
          GestureDetector(
            onTap: _pickImage, 
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 65, 
                  backgroundColor: Colors.grey[200], 
                  backgroundImage: _imageFile != null ? FileImage(_imageFile!) as ImageProvider : (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) ? NetworkImage(user.profileImageUrl!) as ImageProvider : null,
                  child: (_imageFile == null && (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)) ? const Icon(Icons.person, size: 65, color: Colors.grey) : null,
                ), 
                Positioned(
                  right: 0, bottom: 0, 
                  child: Container(
                    padding: const EdgeInsets.all(8), 
                    decoration: const BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle), 
                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildInput("닉네임", _nickCtrl),
          const SizedBox(height: 20),
          _buildInput("한줄소개", _bioCtrl),
          const SizedBox(height: 60),
          SizedBox(
            width: double.infinity, 
            height: 55, 
            child: ElevatedButton(
              onPressed: vm.isLoading ? null : () async { 
                await vm.updateProfile(nickname: _nickCtrl.text.trim(), bio: _bioCtrl.text.trim(), imageFile: _imageFile); 
                if (mounted) Navigator.pop(context); 
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
              ), 
              child: vm.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("변경 내용 저장", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50))),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl, 
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          fillColor: Colors.grey[50],
          filled: true,
        ),
      ),
    ]);
  }
}

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
        backgroundColor: const Color(0xFF4CAF50), 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: profileVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(widget.isFollowingList ? Icons.person_outline : Icons.people_outline, size: 64, color: Colors.grey[400]), const SizedBox(height: 16), Text(widget.isFollowingList ? "팔로잉한 사용자가 없습니다." : "팔로워가 없습니다.", style: TextStyle(color: Colors.grey[600], fontSize: 16))]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isMe = user.uid == myUid;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(radius: 28, backgroundColor: Colors.grey[300], backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) ? NetworkImage(user.profileImageUrl!) : null, child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.white) : null),
                      title: Text(user.nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(user.bio ?? "함께 산책해요!", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      trailing: isMe ? null : ElevatedButton(
                        onPressed: () async { 
                          await socialVM.toggleFollow(user.uid); 
                          final profileVM = context.read<ProfileViewModel>(); 
                          widget.isFollowingList ? await profileVM.fetchFollowingUsers(widget.userId) : await profileVM.fetchFollowerUsers(widget.userId); 
                        }, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: socialVM.isFollowing(user.uid) ? Colors.grey[200] : const Color(0xFFFF9800), 
                          foregroundColor: socialVM.isFollowing(user.uid) ? Colors.black87 : Colors.white, 
                          elevation: 0, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                        ), 
                        child: Text(socialVM.isFollowing(user.uid) ? "팔로잉" : "팔로우", style: const TextStyle(fontWeight: FontWeight.bold))
                      ),
                      onTap: isMe ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileView(user: user))),
                    );
                  },
                ),
    );
  }
}
