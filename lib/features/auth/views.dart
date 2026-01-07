import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
import '../pet/views.dart';

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
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: const Text("계정이 없으신가요? 회원가입"),
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
// 2. 회원가입 화면 (SignUpScreen)
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
// 3. 내 정보 화면 (ProfileScreen)
// -----------------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.userModel;

    return Scaffold(
      appBar: AppBar(title: const Text("내 정보")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50, backgroundColor: Colors.grey[300],

              // [수정 포인트] null 체크뿐만 아니라 빈 문자열("")인지도 함께 확인합니다.
              backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              // [수정 포인트] 이미지가 없거나 비어있을 때만 기본 아이콘을 보여줍니다.
              child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(user?.nickname ?? "익명 유저", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem("팔로워", "${user?.stats.followerCount ?? 0}"),
                  _buildStatItem("팔로잉", "${user?.stats.followingCount ?? 0}"),
                  _buildStatItem("총 산책", "${user?.stats.totalWalkDistance.toStringAsFixed(1) ?? 0}km"),
                ],
              ),
            ),
            const Divider(thickness: 8, color: Colors.black12),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("내 반려동물", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  PetScreen(),
                ],
              ),
            ),
            const Divider(thickness: 8, color: Colors.black12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("로그아웃", style: TextStyle(color: Colors.red)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("로그아웃"),
                    content: const Text("정말 로그아웃 하시겠습니까?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
                      TextButton(onPressed: () { Navigator.pop(ctx); authVM.logout(); }, child: const Text("로그아웃", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}