import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'viewmodels.dart';
import '../pet/views.dart';
import '../../data/repositories.dart';
import '../walk/models.dart';
import '../profile/viewmodels.dart';

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
      appBar: AppBar(title: const Text("비밀번호 찾기"), elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.black),
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
                  child: ElevatedButton(onPressed: _handleReset, child: const Text("비밀번호 재설정 메일 발송")),
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
                  child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("로그인으로 돌아가기")),
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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
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
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: isLoading ? null : _handleSignUp, child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("가입하기"))),
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
        backgroundColor: const Color(0xFF2ECC71),
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
                        Row(
                          children: [
                            Text("게시물 ${_walkRecords.length}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            const SizedBox(width: 12),
                            Text("팔로우 ${user?.stats.followingCount ?? 0}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            const SizedBox(width: 12),
                            Text("팔로워 ${user?.stats.followerCount ?? 0}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          ],
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
// 5. 설정 화면 (SettingsScreen) - 이미지1
// -----------------------------------------------------------------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.read<AuthViewModel>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2ECC71),
        title: const Text("설정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.menu), onPressed: () {})],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildMenuItem(context, "계정 관리", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountManagementScreen()))),
          _buildMenuItem(context, "공개 범위", () {}),
          _buildMenuItem(context, "권한 관리", () {}),
          _buildMenuItem(context, "차단된 계정", () {}),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: OutlinedButton(
              onPressed: () {
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
              },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text("로그아웃", style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          border: Border.all(color: Colors.black),
        ),
        child: Center(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. 계정 관리 화면 (AccountManagementScreen) - 이미지2 좌측
// -----------------------------------------------------------------------------
class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.userModel;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2ECC71),
        title: const Text("계정 관리", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.menu), onPressed: () {})],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("계정 정보", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("이메일", style: TextStyle(fontSize: 18)),
                Text(user?.email ?? "", style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("닉네임", style: TextStyle(fontSize: 18)),
                Text(user?.nickname ?? "", style: const TextStyle(fontSize: 18, color: Colors.black)),
              ],
            ),
            const SizedBox(height: 40),
            const Text("계정 보안", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildActionItem("비밀번호 변경", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordChangeStep1Screen()))),
            const Spacer(),
            Center(
              child: OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("회원 탈퇴"),
                      content: const Text("정말 탈퇴하시겠습니까? 모든 데이터가 삭제됩니다."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
                        TextButton(onPressed: () async {
                          await authVM.deleteAccount();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }
                        }, child: const Text("회원탈퇴", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black)),
                child: const Text("회원탈퇴", style: TextStyle(color: Colors.black)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFFFDF5E6), border: Border.all(color: Colors.black)),
        child: Text(title, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7. 비밀번호 변경 - 1단계: 현재 비번 확인 (이미지2 중간)
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
        backgroundColor: const Color(0xFF2ECC71),
        title: const Text("비밀번호 변경", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.menu), onPressed: () {})],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text("댕댕워킹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            const Text("비밀번호 확인", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
              decoration: BoxDecoration(border: Border.all(color: Colors.black)),
              child: Text(user?.email ?? "", style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "비밀번호를 입력하세요..", 
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
              ),
            ),
            const SizedBox(height: 20),
            Center(
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(color: Colors.black)),
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
    );
  }
}

// -----------------------------------------------------------------------------
// 8. 비밀번호 변경 - 2단계: 새 비번 입력 (이미지2 우측)
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
        backgroundColor: const Color(0xFF2ECC71),
        title: const Text("비밀번호 변경", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.menu), onPressed: () {})],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text("댕댕워킹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            const Text("비밀번호 변경", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            _buildPwField("변경할 비밀번호", _newPwCtrl),
            const SizedBox(height: 10),
            _buildPwField("변경 비밀번호 확인", _confirmPwCtrl),
            const SizedBox(height: 40),
            Center(
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(color: Colors.black)),
                child: const Text("변경"),
              ),
            ),
            const SizedBox(height: 80),
          ],
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
