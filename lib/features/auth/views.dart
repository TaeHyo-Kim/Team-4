import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("프로필", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _showSettingsMenu(context, authVM)),
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

  void _showSettingsMenu(BuildContext context, AuthViewModel authVM) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("로그아웃", style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx); _showLogoutDialog(context, authVM); },
          ),
        ],
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

  void _showLogoutDialog(BuildContext context, AuthViewModel authVM) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("로그아웃"),
        content: const Text("정말 로그아웃 하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(onPressed: () { authVM.logout(); Navigator.pop(ctx); }, child: const Text("로그아웃", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
