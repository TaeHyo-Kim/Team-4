import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 입력 컨트롤러
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();

  // 모드 전환 (로그인 <-> 회원가입)
  bool _isSignup = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: Colors.grey[50], // 배경색을 은은하게
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 로고 영역
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, size: 80, color: Colors.amber),
              ),
              const SizedBox(height: 24),
              Text(
                _isSignup ? '반려동물과 함께 산책해요!' : '다시 오셨군요!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 40),

              // 2. 입력 필드 영역
              _buildTextField(controller: _emailCtrl, label: '이메일', icon: Icons.email, type: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(controller: _pwCtrl, label: '비밀번호', icon: Icons.lock, obscure: true),

              // 회원가입일 때만 닉네임 필드 보이기
              if (_isSignup) ...[
                const SizedBox(height: 16),
                _buildTextField(controller: _nickCtrl, label: '닉네임 (중복 불가)', icon: Icons.person),
              ],

              const SizedBox(height: 24),

              // 3. 에러 메시지 표시 영역
              if (authVM.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(authVM.errorMessage!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),

              // 4. 버튼 영역
              if (authVM.isLoading)
                const CircularProgressIndicator(color: Colors.amber)
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: () => _handleAuthAction(context),
                    child: Text(
                      _isSignup ? '회원가입 완료' : '로그인',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 5. 모드 전환 버튼
              TextButton(
                onPressed: () {
                  setState(() => _isSignup = !_isSignup);
                  context.read<AuthViewModel>().clearError(); // 화면 전환 시 에러 초기화
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(text: _isSignup ? '이미 계정이 있으신가요? ' : '계정이 없으신가요? '),
                      TextSpan(
                        text: _isSignup ? '로그인' : '회원가입',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 텍스트 필드 디자인 위젯
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.amber, width: 2)),
      ),
    );
  }

  // 로그인/회원가입 버튼 클릭 시 실행 로직
  void _handleAuthAction(BuildContext context) async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    final nick = _nickCtrl.text.trim();
    final vm = context.read<AuthViewModel>();

    // 간단한 유효성 검사
    if (email.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      return;
    }

    if (_isSignup && nick.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    // 실제 실행
    if (_isSignup) {
      await vm.signUp(email: email, password: pw, nickname: nick);
      if (vm.errorMessage == null && mounted) {
        // 회원가입 성공 시 -> 로그인 모드로 자동 전환 or 자동 로그인됨
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원가입 성공! 환영합니다.')));
      }
    } else {
      await vm.login(email: email, password: pw);
    }
  }
}