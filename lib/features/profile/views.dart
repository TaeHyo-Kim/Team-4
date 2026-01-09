import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../auth/viewmodels.dart';
import '../pet/views.dart'; 
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
        backgroundColor: const Color(0xFF2ECC71), // 예전 녹색 헤더
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showSettingsSheet(context, authVM),
          )
        ],
      ),
      body: ListView( // 레이아웃 겹침 방지를 위해 ListView 사용
        padding: EdgeInsets.zero,
        children: [
          // 1. 프로필 상단 정보 (이미지, 이름, 소개, 게시물/팔로워/팔로잉 + 우측 편집 버튼)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 35, 15, 25), // 위아래 간격을 충분히 확보
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 프로필 이미지
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 45, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 15),
                // 텍스트 정보 영역
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user?.nickname ?? "익명 유저", 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(user?.bio ?? "좋은 하루 되세요", 
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      // 게시물 / 팔로우 / 팔로잉 (한 줄에 표시)
                      Row(
                        children: [
                          Text("게시물 ${user?.stats.postCount ?? 0}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Text("팔로우 ${user?.stats.followingCount ?? 0}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Text("팔로워 ${user?.stats.followerCount ?? 0}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 프로필 편집 버튼
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditView())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("프로필 편집", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),
          const Divider(thickness: 1, color: Colors.black12),

          // 2. 반려동물 목록
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: PetScreen(),
          ),

          const SizedBox(height: 80),

          // 3. 산책 기록 없음 안내
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
    );
  }

  void _showSettingsSheet(BuildContext context, AuthViewModel authVM) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("설정", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("로그아웃", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                authVM.logout();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
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
      appBar: AppBar(title: const Text("프로필 수정"), backgroundColor: const Color(0xFF2ECC71)),
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
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFF3498DB), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
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
