import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
// [중요] 펫 리스트 위젯을 가져오기 위해 import 합니다.
// (경로가 다르다면 본인 프로젝트 구조에 맞춰 수정해주세요)
import '../pet/views.dart';

// -----------------------------------------------------------------------------
// 1. 로그인 화면
// -----------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // 유효성 검사 키
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isObscure = true; // 비밀번호 숨김 여부

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        await context.read<AuthViewModel>().login(
          _emailCtrl.text.trim(),
          _pwCtrl.text.trim(),
        );
        // 성공 시 main.dart의 StreamBuilder가 화면 전환 처리
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인 실패: ${e.toString().split(']').last.trim()}")),
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
                const Text(
                  "댕댕워킹",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // 이메일
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "이메일",
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return '이메일을 입력해주세요.';
                    if (!value.contains('@')) return '올바른 이메일 형식이 아닙니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 비밀번호
                TextFormField(
                  controller: _pwCtrl,
                  decoration: InputDecoration(
                    labelText: "비밀번호",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                  obscureText: _isObscure,
                  validator: (value) {
                    if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("로그인"),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
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
// 2. 회원가입 화면
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
  bool _agreedToTerms = false; // 약관 동의 상태

  void _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("서비스 이용 약관 및 위치 정보 제공에 동의해주세요.")),
      );
      return;
    }

    try {
      await context.read<AuthViewModel>().signUp(
        _emailCtrl.text.trim(),
        _pwCtrl.text.trim(),
        _nickCtrl.text.trim(),
      );

      // 회원가입 성공 시 자동 로그인 되므로, 로딩 상태 해제 후 팝
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("가입 실패: ${e.toString().split(']').last.trim()}")),
      );
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
              // 이메일
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: "이메일",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || !value.contains('@')) return '올바른 이메일을 입력하세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 비밀번호
              TextFormField(
                controller: _pwCtrl,
                decoration: InputDecoration(
                  labelText: "비밀번호 (6자리 이상)",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
                obscureText: _isObscure,
                validator: (value) {
                  if (value == null || value.length < 6) return '비밀번호는 6자리 이상이어야 합니다.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 닉네임
              TextFormField(
                controller: _nickCtrl,
                decoration: const InputDecoration(
                  labelText: "닉네임",
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: "다른 유저에게 표시될 이름입니다.",
                ),
                validator: (value) {
                  if (value == null || value.length < 2) return '닉네임은 2글자 이상 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 약관 동의 체크박스
              CheckboxListTile(
                value: _agreedToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreedToTerms = value ?? false;
                  });
                },
                title: const Text("서비스 이용 및 위치 정보 제공 약관에 동의합니다. (필수)", style: TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.amber,
              ),
              const SizedBox(height: 30),

              // 가입 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSignUp,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("가입하기"),
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
// 3. 내 정보 (프로필) 화면
// -----------------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthViewModel에서 현재 로그인한 유저 정보를 가져옴
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.userModel;

    return Scaffold(
      appBar: AppBar(title: const Text("내 정보")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // [A] 유저 프로필 섹션
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: user?.profileImageUrl != null
                  ? NetworkImage(user!.profileImageUrl!)
                  : null,
              child: user?.profileImageUrl == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              user?.nickname ?? "익명 유저",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),

            // 통계 (간단 요약)
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

            // [B] 내 강아지 리스트 섹션
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("내 반려동물", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  // 여기서 features/pet/views.dart에 정의된 위젯을 사용
                  PetScreen(),
                ],
              ),
            ),

            const Divider(thickness: 8, color: Colors.black12),

            // [C] 로그아웃 버튼
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("로그아웃", style: TextStyle(color: Colors.red)),
              onTap: () {
                // 로그아웃 확인
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("로그아웃"),
                      content: const Text("정말 로그아웃 하시겠습니까?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.read<AuthViewModel>().logout();
                          },
                          child: const Text("로그아웃", style: TextStyle(color: Colors.red)),
                        )
                      ],
                    )
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 통계 아이템 빌더 (내부 함수)
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}