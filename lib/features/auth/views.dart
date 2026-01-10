import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'viewmodels.dart';
import '../pet/views.dart';
import '../../data/repositories.dart';
import '../walk/models.dart';
import '../profile/viewmodels.dart';
import 'permission_request_view.dart';
import '../../core/permission_service.dart';
import '../../core/notification_service.dart';

// -----------------------------------------------------------------------------
// 1. 로그인 화면 (LoginScreen)
// -----------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isObscure = true;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final vm = context.read<AuthViewModel>();
      await vm.login(_emailCtrl.text.trim(), _pwCtrl.text.trim());

      if (vm.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pets, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                const Text("댕댕워킹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: "이메일", prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? '올바른 이메일 형식을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: "비밀번호",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isObscure = !_isObscure)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력해주세요.' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("로그인"),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text("비밀번호 찾기"),
                    ),
                    const Text("|"),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                      child: const Text("회원가입"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. 비밀번호 찾기 화면 (ForgotPasswordScreen)
// -----------------------------------------------------------------------------
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  int _step = 1;

  void _handleReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("올바른 이메일을 입력하세요.")));
      return;
    }
    final vm = context.read<AuthViewModel>();
    await vm.sendPasswordResetEmail(email);
    if (vm.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.redAccent));
    } else if (mounted) {
      setState(() => _step = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("비밀번호 찾기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 80, color: Colors.amber),
              const SizedBox(height: 20),
              const Text("댕댕워킹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              if (_step == 1) ...[
                const Text("비밀번호를 잊으셨나요?\n가입하신 이메일을 입력해주세요.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: "이메일", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _handleReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("비밀번호 재설정 메일 발송"),
                  ),
                ),
              ] else ...[
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text("'${_emailCtrl.text}'로\n재설정 메일을 보냈습니다.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("메일함의 링크를 통해 비밀번호를 변경한 후\n다시 로그인해주세요.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("로그인으로 돌아가기"),
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. 회원가입 화면 (SignUpScreen)
// -----------------------------------------------------------------------------
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  bool _isObscure = true;
  bool _agreedToTerms = false;

  void _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("서비스 이용 및 위치 정보 제공 약관에 동의해주세요.")));
      return;
    }
    final vm = context.read<AuthViewModel>();
    await vm.signUp(_emailCtrl.text.trim(), _pwCtrl.text.trim(), _nickCtrl.text.trim());

    if (vm.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.redAccent));
    } else if (mounted) {
      // 회원가입 성공 시 권한 요청 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PermissionRequestView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text("회원가입", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "이메일", prefixIcon: Icon(Icons.email_outlined)), validator: (v) => (v == null || !v.contains('@')) ? '올바른 이메일을 입력하세요.' : null),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pwCtrl, obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: "비밀번호 (6자리 이상)", prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isObscure = !_isObscure)),
                ),
                validator: (v) => (v == null || v.length < 6) ? '비밀번호는 6자리 이상이어야 합니다.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _nickCtrl, decoration: const InputDecoration(labelText: "닉네임", prefixIcon: Icon(Icons.person_outline), helperText: "다른 유저에게 표시될 이름입니다."), validator: (v) => (v == null || v.length < 2) ? '닉네임은 2글자 이상 입력해주세요.' : null),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _agreedToTerms, onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                title: const Text("서비스 이용 및 위치 정보 제공 약관에 동의합니다. (필수)", style: TextStyle(fontSize: 14)),
                activeColor: Colors.amber, controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("가입하기"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. 내 정보 화면 (ProfileScreen)
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<WalkRecordModel> _walkRecords = [];
  bool _isLoadingWalks = false;

  @override
  void initState() {
    super.initState();
    _loadWalkRecords();
  }

  Future<void> _loadWalkRecords() async {
    final authVM = context.read<AuthViewModel>();
    final user = authVM.userModel;
    if (user == null) return;

    setState(() => _isLoadingWalks = true);
    try {
      final walkRepo = WalkRepository();
      final walks = await walkRepo.getMyWalks(user.uid);
      setState(() {
        _walkRecords = walks;
        _isLoadingWalks = false;
      });
    } catch (e) {
      debugPrint("산책 기록 로드 실패: $e");
      setState(() => _isLoadingWalks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.userModel;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        key: const ValueKey('auth_profile_appbar'),
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("프로필", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                        ? NetworkImage(user.profileImageUrl!) : null,
                    child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                        ? const Icon(Icons.pets, size: 40, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nickname ?? "익명 유저", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(user?.bio ?? "좋은하루 되세요", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              Text("게시물 ${_walkRecords.length}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                              const SizedBox(width: 12),
                              Text("팔로우 ${user?.stats.followingCount ?? 0}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                              const SizedBox(width: 12),
                              Text("팔로워 ${user?.stats.followerCount ?? 0}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showEditProfileDialog(context, authVM, user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("프로필 편집"),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoadingWalks
                  ? const Center(child: CircularProgressIndicator())
                  : _walkRecords.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("아직 산책 기록이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 14))))
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                          itemCount: _walkRecords.length,
                          itemBuilder: (context, index) {
                            final walk = _walkRecords[index];
                            final photoUrl = walk.photoUrls.isNotEmpty ? walk.photoUrls[0] : null;
                            return GestureDetector(
                              onTap: () => _showWalkDetail(context, walk),
                              child: Container(
                                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                child: photoUrl != null && photoUrl.isNotEmpty
                                    ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(photoUrl, fit: BoxFit.cover))
                                    : const Icon(Icons.directions_walk, size: 40, color: Colors.grey),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthViewModel authVM, dynamic user) {
    final nicknameCtrl = TextEditingController(text: user?.nickname ?? '');
    final bioCtrl = TextEditingController(text: user?.bio ?? '');
    File? selectedImage;
    final picker = ImagePicker();
    final permissionService = PermissionService();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("프로필 수정"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    // 이미지 권한 확인
                    final photosStatus = await permissionService.getPhotosPermissionStatus();
                    if (photosStatus != ph.PermissionStatus.granted) {
                      // 권한이 없으면 요청
                      final granted = await permissionService.requestPhotosPermission();
                      if (!granted) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('이미지 권한이 필요합니다. 설정에서 권한을 허용해주세요.')),
                        );
                        return;
                      }
                    }

                    // 권한이 있으면 이미지 선택
                    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) setDialogState(() => selectedImage = File(pickedFile.path));
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: selectedImage != null ? FileImage(selectedImage!) : null,
                    child: selectedImage == null ? const Icon(Icons.camera_alt, color: Colors.grey) : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(controller: nicknameCtrl, decoration: const InputDecoration(labelText: "닉네임", border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: "한줄소개", border: OutlineInputBorder()), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
            ElevatedButton(
              onPressed: () async {
                final profileVM = context.read<ProfileViewModel>();
                await profileVM.updateProfile(nickname: nicknameCtrl.text.trim(), bio: bioCtrl.text.trim(), imageFile: selectedImage);
                await authVM.fetchUserProfile();
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text("수정 완료"),
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

// -----------------------------------------------------------------------------
// 5. 설정 화면 (SettingsScreen)
// -----------------------------------------------------------------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.read<AuthViewModel>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        key: const ValueKey('settings_appbar'),
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("설정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildMenuItem(context, Icons.person_outline, "계정 관리", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountManagementScreen()))),
          _buildMenuItem(context, Icons.visibility_outlined, "공개 범위", () {}),
          _buildMenuItem(context, Icons.lock_open_outlined, "권한 관리", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionManagementScreen()))),
          _buildMenuItem(context, Icons.block_flipped, "차단된 계정", () {}),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  _showLogoutDialog(context, authVM);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text("로그아웃", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthViewModel authVM) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("로그아웃"),
        content: const Text("정말 로그아웃 하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(onPressed: () { Navigator.pop(ctx); authVM.logout(); Navigator.pop(context); }, child: const Text("로그아웃", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. 계정 관리 화면 (AccountManagementScreen)
// -----------------------------------------------------------------------------
class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.userModel;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        key: const ValueKey('account_management_appbar'),
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("계정 관리", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("계정 정보", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildSimpleRow("이메일", user?.email ?? ""),
                  const Divider(height: 24, thickness: 0.5),
                  _buildSimpleRow("닉네임", user?.nickname ?? ""),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text("계정 보안", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // 비밀번호 변경 버튼 - 설정 화면 메뉴 디자인과 동일하게 수정
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: Color(0xFF4CAF50)),
                title: const Text("비밀번호 변경", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordChangeStep1Screen())),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const Spacer(),
            Center(
              child: SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    _showDeleteAccountDialog(context, authVM);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text("회원탈퇴", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthViewModel authVM) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("회원 탈퇴"),
        content: const Text("정말 탈퇴하시겠습니까? 모든 데이터가 삭제되며 복구할 수 없습니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(onPressed: () async {
            await authVM.deleteAccount();
            if (ctx.mounted) {
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }, child: const Text("탈퇴하기", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7. 비밀번호 변경 - 1단계: 현재 비번 확인
// -----------------------------------------------------------------------------
class PasswordChangeStep1Screen extends StatefulWidget {
  const PasswordChangeStep1Screen({super.key});

  @override
  State<PasswordChangeStep1Screen> createState() => _PasswordChangeStep1ScreenState();
}

class _PasswordChangeStep1ScreenState extends State<PasswordChangeStep1Screen> {
  final _pwCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthViewModel>().userModel;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("비밀번호 확인", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 80, color: Colors.amber),
              const SizedBox(height: 20),
              const Text("댕댕워킹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              const Text("보안을 위해 현재 비밀번호를 입력해주세요.", style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Text(user?.email ?? "", style: const TextStyle(fontSize: 16, color: Colors.black54)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: "현재 비밀번호",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_pwCtrl.text.isEmpty) return;
                    final vm = context.read<AuthViewModel>();
                    final success = await vm.reauthenticate(_pwCtrl.text);
                    if (success) {
                      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordChangeStep2Screen()));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage ?? "비밀번호가 틀렸습니다."), backgroundColor: Colors.redAccent));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("확인"),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text("비밀번호가 기억나지 않으세요?", style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 8. 비밀번호 변경 - 2단계: 새 비번 입력
// -----------------------------------------------------------------------------
class PasswordChangeStep2Screen extends StatefulWidget {
  const PasswordChangeStep2Screen({super.key});

  @override
  State<PasswordChangeStep2Screen> createState() => _PasswordChangeStep2ScreenState();
}

class _PasswordChangeStep2ScreenState extends State<PasswordChangeStep2Screen> {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("새 비밀번호 설정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 80, color: Colors.amber),
              const SizedBox(height: 20),
              const Text("댕댕워킹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              const Text("새로운 비밀번호를 입력해주세요.", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              TextField(
                controller: _newPwCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "새 비밀번호",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPwCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "비밀번호 확인",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_newPwCtrl.text.isEmpty || _newPwCtrl.text != _confirmPwCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")));
                      return;
                    }
                    try {
                      await FirebaseAuth.instance.currentUser?.updatePassword(_newPwCtrl.text);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("비밀번호가 변경되었습니다. 다시 로그인해주세요.")));
                        context.read<AuthViewModel>().logout();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("변경 실패: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("변경 완료"),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPwField(String label, TextEditingController ctrl) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 14))),
        Expanded(
          child: TextField(
            controller: ctrl, 
            obscureText: true, 
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 8. 권한 관리 화면 (PermissionManagementScreen)
// -----------------------------------------------------------------------------
class PermissionManagementScreen extends StatefulWidget {
  const PermissionManagementScreen({super.key});

  @override
  State<PermissionManagementScreen> createState() => _PermissionManagementScreenState();
}

class _PermissionManagementScreenState extends State<PermissionManagementScreen> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  final NotificationService _notificationService = NotificationService();

  bool _notificationGranted = false;
  bool _locationGranted = false;
  bool _photosGranted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 포그라운드로 돌아올 때 권한 상태 재확인
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    // 실제 시스템 권한 상태 확인
    final notificationStatus = await _permissionService.getNotificationPermissionStatus();
    final locationStatus = await _permissionService.getLocationPermissionStatus();
    final photosStatus = await _permissionService.getPhotosPermissionStatus();

    final actualNotificationGranted = notificationStatus.isGranted;
    final actualLocationGranted = locationStatus.isGranted;
    final actualPhotosGranted = photosStatus.isGranted;

    // Firestore에도 실제 상태 반영
    if (actualNotificationGranted != _notificationGranted) {
      await _permissionService.updatePermissionStatus('notification', actualNotificationGranted);
    }
    if (actualLocationGranted != _locationGranted) {
      await _permissionService.updatePermissionStatus('location', actualLocationGranted);
    }
    if (actualPhotosGranted != _photosGranted) {
      await _permissionService.updatePermissionStatus('photos', actualPhotosGranted);
    }

    setState(() {
      _notificationGranted = actualNotificationGranted;
      _locationGranted = actualLocationGranted;
      _photosGranted = actualPhotosGranted;
      _isLoading = false;
    });
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _permissionService.requestNotificationPermission();
      setState(() {
        _notificationGranted = granted;
        _isLoading = false;
      });
      if (granted) {
        await _notificationService.initialize();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 권한이 허용되었습니다.')),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('알림 권한이 거부되었습니다'),
            content: const Text('설정에서 권한을 허용하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('나중에'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _permissionService.openAppSettings();
                },
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알림 권한 요청 실패: $e')),
      );
    }
  }

  Future<void> _disableNotificationPermission() async {
    // Android에서는 프로그래밍적으로 권한을 거부할 수 없으므로 설정 앱으로 이동
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한 비활성화'),
        content: const Text('알림 권한을 비활성화하려면 설정 앱에서 직접 변경해야 합니다. 설정으로 이동하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _permissionService.openAppSettings();
              // 설정에서 돌아올 때 권한 상태 재확인
              Future.delayed(const Duration(seconds: 2), () {
                _checkPermissions();
              });
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _permissionService.requestLocationPermission();
      setState(() {
        _locationGranted = granted;
        _isLoading = false;
      });
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 허용되었습니다.')),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 권한이 거부되었습니다'),
            content: const Text('설정에서 권한을 허용하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('나중에'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _permissionService.openAppSettings();
                },
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 권한 요청 실패: $e')),
      );
    }
  }

  Future<void> _disableLocationPermission() async {
    // Android에서는 프로그래밍적으로 권한을 거부할 수 없으므로 설정 앱으로 이동
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 비활성화'),
        content: const Text('위치 권한을 비활성화하려면 설정 앱에서 직접 변경해야 합니다. 설정으로 이동하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _permissionService.openAppSettings();
              // 설정에서 돌아올 때 권한 상태 재확인
              Future.delayed(const Duration(seconds: 2), () {
                _checkPermissions();
              });
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPhotosPermission() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _permissionService.requestPhotosPermission();
      setState(() {
        _photosGranted = granted;
        _isLoading = false;
      });
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 권한이 허용되었습니다.')),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('이미지 권한이 거부되었습니다'),
            content: const Text('설정에서 권한을 허용하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('나중에'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _permissionService.openAppSettings();
                },
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 권한 요청 실패: $e')),
      );
    }
  }

  Future<void> _disablePhotosPermission() async {
    // Android에서는 프로그래밍적으로 권한을 거부할 수 없으므로 설정 앱으로 이동
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 권한 비활성화'),
        content: const Text('이미지 권한을 비활성화하려면 설정 앱에서 직접 변경해야 합니다. 설정으로 이동하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _permissionService.openAppSettings();
              // 설정에서 돌아올 때 권한 상태 재확인
              Future.delayed(const Duration(seconds: 2), () {
                _checkPermissions();
              });
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionType 권한이 거부되었습니다'),
        content: const Text('설정에서 권한을 허용하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        key: const ValueKey('permission_management_appbar'),
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "권한 관리",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkPermissions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '앱 권한 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '권한을 허용하면 더 나은 서비스를 이용하실 수 있습니다.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    
                    // 알림 권한
                    _buildPermissionCard(
                      icon: Icons.notifications_outlined,
                      title: "알림",
                      description: "팔로우, 피드 업로드 등의 알림을 받을 수 있습니다",
                      isGranted: _notificationGranted,
                      onEnable: _requestNotificationPermission,
                      onDisable: _disableNotificationPermission,
                    ),
                    const SizedBox(height: 12),
                    
                    // 위치 권한
                    _buildPermissionCard(
                      icon: Icons.location_on_outlined,
                      title: "위치",
                      description: "산책 경로 기록 및 주변 사용자 탐색에 필요합니다",
                      isGranted: _locationGranted,
                      onEnable: _requestLocationPermission,
                      onDisable: _disableLocationPermission,
                    ),
                    const SizedBox(height: 12),
                    
                    // 이미지 권한
                    _buildPermissionCard(
                      icon: Icons.image_outlined,
                      title: "이미지",
                      description: "프로필 사진 및 반려동물 사진 등록에 필요합니다",
                      isGranted: _photosGranted,
                      onEnable: _requestPhotosPermission,
                      onDisable: _disablePhotosPermission,
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      '권한 상태는 실시간으로 업데이트됩니다. 새로고침을 눌러 최신 상태를 확인하세요.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onEnable,
    required VoidCallback onDisable,
  }) {
    return Card(
      elevation: 2,
      color: isGranted ? Colors.green[50] : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isGranted ? Colors.green : Colors.grey[300]!,
          width: isGranted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (isGranted) {
            onDisable();
          } else {
            onEnable();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGranted ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isGranted ? Colors.green[900] : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isGranted)
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (isGranted) {
                    onDisable();
                  } else {
                    onEnable();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isGranted ? Colors.green : Colors.grey[400],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  isGranted ? '활성화됨' : '활성화',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
