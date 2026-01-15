import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'viewmodels.dart';
import '../social/views.dart'; // [추가] 차단된 계정 화면 이동을 위해 필요
import 'permission_request_view.dart';
import '../../core/permission_service.dart';
import '../../core/notification_service.dart';

// [공통] 커스텀 로딩 위젯
class AppLoadingIndicator extends StatelessWidget {
  final Color color;
  final double size;
  const AppLoadingIndicator({super.key, this.color = const Color(0xFF4CAF50), this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

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
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'asset/images/logo.webp',
                  width: 280,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 100, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(height: 50),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: "이메일",
                    prefixIcon: const Icon(Icons.email, color: Color(0xFF4CAF50)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? '올바른 이메일 형식을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: "비밀번호",
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF4CAF50)),
                    suffixIcon: IconButton(icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _isObscure = !_isObscure)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력해주세요.' : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    child: isLoading ? const AppLoadingIndicator(color: Colors.white) : const Text("로그인", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text("비밀번호 찾기", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                    ),
                    const Text("|", style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                      child: const Text("회원가입", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
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
      backgroundColor: Colors.white,
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
              Image.asset('asset/images/logo.webp', width: 280, errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 100, color: Color(0xFF4CAF50))),
              const SizedBox(height: 40),
              if (_step == 1) ...[
                const Text("비밀번호를 잊으셨나요?\n가입하신 이메일을 입력해주세요.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: "이메일", 
                    prefixIcon: const Icon(Icons.email, color: Color(0xFF4CAF50)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: _handleReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("재설정 메일 발송", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                const Icon(Icons.check_circle, size: 80, color: Color(0xFF4CAF50)),
                const SizedBox(height: 24),
                Text("'${_emailCtrl.text}'로\n재설정 메일을 보냈습니다.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("메일함의 링크를 통해 비밀번호를 변경한 후\n다시 로그인해주세요.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("로그인으로 돌아가기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      backgroundColor: Colors.white,
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
              TextFormField(
                controller: _emailCtrl, 
                decoration: InputDecoration(
                  labelText: "이메일", 
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF4CAF50)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                ), 
                validator: (v) => (v == null || !v.contains('@')) ? '올바른 이메일을 입력하세요.' : null
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pwCtrl, obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: "비밀번호 (6자리 이상)", 
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4CAF50)),
                  suffixIcon: IconButton(icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _isObscure = !_isObscure)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                ),
                validator: (v) => (v == null || v.length < 6) ? '비밀번호는 6자리 이상이어야 합니다.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nickCtrl, 
                decoration: InputDecoration(
                  labelText: "닉네임", 
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4CAF50)),
                  helperText: "다른 유저에게 표시될 이름입니다.",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                ), 
                validator: (v) => (v == null || v.length < 2) ? '닉네임은 2글자 이상 입력해주세요.' : null
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _agreedToTerms, onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                title: const Text("서비스 이용 및 위치 정보 제공 약관에 동의합니다. (필수)", style: TextStyle(fontSize: 14)),
                activeColor: const Color(0xFF4CAF50), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isLoading ? const AppLoadingIndicator(color: Colors.white) : const Text("가입하기", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
// 4. 설정 화면 (SettingsScreen)
// -----------------------------------------------------------------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.read<AuthViewModel>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("설정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildMenuItem(context, Icons.person_outline, "계정 관리", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountManagementScreen()))),
          _buildMenuItem(context, Icons.visibility_outlined, "공개 범위", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisibilitySettingsScreen()))),
          _buildMenuItem(context, Icons.lock_open_outlined, "권한 관리", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionManagementScreen()))),
          _buildMenuItem(context, Icons.block_flipped, "차단된 계정", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()))),
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
                  backgroundColor: const Color(0xFFFF9800), 
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF1F8E9), 
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 48, color: Color(0xFF4CAF50)),
              const SizedBox(height: 16),
              const Text("로그아웃", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("정말 로그아웃 하시겠습니까?", textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("취소", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { 
                        Navigator.pop(ctx); 
                        authVM.logout(); 
                        Navigator.pop(context); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("로그아웃", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. 계정 관리 화면 (AccountManagementScreen)
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
                border: Border.all(color: Colors.grey[100]!),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[100]!),
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
                    backgroundColor: const Color(0xFFFF9800), 
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
      barrierDismissible: !authVM.isLoading, // 로딩 중에는 창 닫기 방지
      builder: (ctx) => Consumer<AuthViewModel>( // 내부 상태 감시를 위해 Consumer 사용
        builder: (context, vm, child) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("회원 탈퇴"),
          content: vm.isLoading
              ? const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoadingIndicator(),
              SizedBox(height: 16),
              Text("계정 정보를 삭제 중입니다..."),
            ],
          )
              : const Text("정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다."),
          actions: vm.isLoading ? [] : [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await vm.deleteAccount();
                if (!context.mounted) return;

                if (vm.errorMessage != null) {
                  // 재인증 필요 등 에러 발생 시
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.redAccent),
                  );
                  Navigator.pop(ctx);
                } else {
                  // 탈퇴 성공 시: 로그인 화면으로 보내고 스택 제거
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              child: const Text("탈퇴하기", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. 비밀번호 변경 - 1단계: 현재 비번 확인
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
    final isLoading = context.watch<AuthViewModel>().isLoading;
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
              Image.asset('asset/images/logo.webp', width: 280, errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 100, color: Color(0xFF4CAF50))),
              const SizedBox(height: 40),
              const Text("보안을 위해 현재 비밀번호를 입력해주세요.", style: TextStyle(fontSize: 16, color: Color(0xFF2C3E50))),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
                child: Text(user?.email ?? "", style: const TextStyle(fontSize: 16, color: Colors.black54)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "현재 비밀번호",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (_pwCtrl.text.isEmpty) return;
                    final vm = context.read<AuthViewModel>();
                    final success = await vm.reauthenticate(_pwCtrl.text);
                    if (success) {
                      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => PasswordChangeStep2Screen(currentPassword: _pwCtrl.text)));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage ?? "비밀번호가 틀렸습니다."), backgroundColor: Colors.redAccent));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isLoading ? const AppLoadingIndicator(color: Colors.white) : const Text("확인", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text("비밀번호가 기억나지 않으세요?", style: TextStyle(color: Color(0xFF4CAF50))),
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
// 7. 비밀번호 변경 - 2단계: 새 비번 입력
// -----------------------------------------------------------------------------
class PasswordChangeStep2Screen extends StatefulWidget {
  final String currentPassword;
  const PasswordChangeStep2Screen({super.key, required this.currentPassword});

  @override
  State<PasswordChangeStep2Screen> createState() => _PasswordChangeStep2ScreenState();
}

class _PasswordChangeStep2ScreenState extends State<PasswordChangeStep2Screen> {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isLoading = context
        .watch<AuthViewModel>()
        .isLoading;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("새 비밀번호 설정",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('asset/images/logo.webp', width: 280,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.pets, size: 100, color: Color(0xFF4CAF50))),
              const SizedBox(height: 40),
              const Text("새로운 비밀번호를 입력해주세요.",
                  style: TextStyle(fontSize: 16, color: Color(0xFF2C3E50))),
              const SizedBox(height: 24),
              TextField(
                controller: _newPwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "새 비밀번호",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                          color: Color(0xFF4CAF50), width: 2)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "비밀번호 확인",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                          color: Color(0xFF4CAF50), width: 2)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (_newPwCtrl.text.isEmpty ||
                        _newPwCtrl.text != _confirmPwCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")));
                      return;
                    }
                    if (_newPwCtrl.text == widget.currentPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                              "새 비밀번호는 기존 비밀번호와 달라야 합니다.")));
                      return;
                    }
                    try {
                      await FirebaseAuth.instance.currentUser?.updatePassword(
                          _newPwCtrl.text);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(
                                "비밀번호가 변경되었습니다. 다시 로그인해주세요.")));
                        context.read<AuthViewModel>().logout();
                        Navigator.of(context).popUntil((route) =>
                        route.isFirst);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("변경 실패: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isLoading ? const AppLoadingIndicator(
                      color: Colors.white) : const Text("변경 완료",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
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
// 9. 공개 범위 설정 화면 (VisibilitySettingsScreen)
// -----------------------------------------------------------------------------
class VisibilitySettingsScreen extends StatefulWidget {
  const VisibilitySettingsScreen({super.key});

  @override
  State<VisibilitySettingsScreen> createState() => _VisibilitySettingsScreenState();
}

class _VisibilitySettingsScreenState extends State<VisibilitySettingsScreen> {
  String _selectedVisibility = 'all';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().userModel;
    _selectedVisibility = user?.visibility ?? 'all';
  }

  Future<void> _updateVisibility(String value) async {
    setState(() => _selectedVisibility = value);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'visibility': value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("공개 범위가 변경되었습니다."),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFDF9),
      appBar: AppBar(
        title: const Text("공개 범위", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity, // 너비 통일
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF4CAF50)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "현재 위치 및 피드의 공개 범위를 설정하여 내 소중한 정보를 보호하세요.",
                      style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildModernOption(
              title: "모두 허용",
              description: "팔로우 여부와 상관 없이 모든 유저에게 공개합니다.",
              value: 'all',
              icon: Icons.public,
            ),
            const SizedBox(height: 16),
            _buildModernOption(
              title: "친구에게만 허용",
              description: "서로 팔로우한 관계인 유저들에게만 공개합니다.",
              value: 'friends',
              icon: Icons.people_outline,
            ),
            const SizedBox(height: 16),
            _buildModernOption(
              title: "허용하지 않음",
              description: "그 누구에게도 정보를 공개하지 않습니다.",
              value: 'none',
              icon: Icons.lock_outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernOption({required String title, required String description, required String value, required IconData icon}) {
    final isSelected = _selectedVisibility == value;
    return InkWell(
      onTap: () => _updateVisibility(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, // 너비 통일
        height: 110, // 높이 고정으로 크기 통일
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: [
            if (isSelected) BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
            else BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, // 수직 중앙 정렬
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF2E7D32) : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(description, 
                    maxLines: 2, // 줄 수 제한
                    overflow: TextOverflow.ellipsis, // 넘치는 텍스트 처리
                    style: TextStyle(fontSize: 13, color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600], height: 1.3)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 10. 권한 관리 화면 (PermissionManagementScreen)
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
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    final notificationStatus = await _permissionService.getNotificationPermissionStatus();
    final locationStatus = await _permissionService.getLocationPermissionStatus();
    final photosStatus = await _permissionService.getPhotosPermissionStatus();

    final actualNotificationGranted = notificationStatus.isGranted;
    final actualLocationGranted = locationStatus.isGranted;
    final actualPhotosGranted = photosStatus.isGranted;

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림 권한이 허용되었습니다.')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 권한이 허용되었습니다.')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 권한이 허용되었습니다.')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disableNotificationPermission() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한 비활성화'),
        content: const Text('알림 권한을 비활성화하려면 설정 앱에서 직접 변경해야 합니다. 설정으로 이동하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _permissionService.openAppSettings();
              Future.delayed(const Duration(seconds: 2), () => _checkPermissions());
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _disableLocationPermission() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 비활성화'),
        content: const Text('위치 권한을 비활성화하려면 설정 앱에서 직접 변경해야 합니다. 설정으로 이동하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _permissionService.openAppSettings();
              Future.delayed(const Duration(seconds: 2), () => _checkPermissions());
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _disablePhotosPermission() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 권한 비활성화'),
        content: const Text('이미지 권한을 비활성화하려면 설정 앱에서 직접 변경해야 합니다. 설정으로 이동하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _permissionService.openAppSettings();
              Future.delayed(const Duration(seconds: 2), () => _checkPermissions());
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text("권한 관리", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
        onRefresh: _checkPermissions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('앱 권한 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 8),
              Text('권한을 허용하면 더 나은 서비스를 이용하실 수 있습니다.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 24),
              _buildPermissionCard(icon: Icons.notifications_outlined, title: "알림", description: "알림을 받을 수 있습니다", isGranted: _notificationGranted, onEnable: _requestNotificationPermission, onDisable: _disableNotificationPermission),
              const SizedBox(height: 12),
              _buildPermissionCard(icon: Icons.location_on_outlined, title: "위치", description: "산책 경로 기록에 필요합니다", isGranted: _locationGranted, onEnable: _requestLocationPermission, onDisable: _disableLocationPermission),
              const SizedBox(height: 12),
              _buildPermissionCard(icon: Icons.image_outlined, title: "이미지", description: "사진 등록에 필요합니다", isGranted: _photosGranted, onEnable: _requestPhotosPermission, onDisable: _disablePerformancePermission),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({required IconData icon, required String title, required String description, required bool isGranted, required VoidCallback onEnable, required VoidCallback onDisable}) {
    return Card(
      elevation: 2,
      color: isGranted ? const Color(0xFFE8F5E9) : Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isGranted ? const Color(0xFF4CAF50) : Colors.grey[300]!, width: isGranted ? 2 : 1)),
      child: InkWell(
        onTap: isGranted ? onDisable : onEnable,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isGranted ? const Color(0xFF4CAF50) : Colors.grey[300], borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))), const SizedBox(width: 8), if (isGranted) const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20)]),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              ElevatedButton(onPressed: isGranted ? onDisable : onEnable, style: ElevatedButton.styleFrom(backgroundColor: isGranted ? const Color(0xFF4CAF50) : Colors.grey[400], foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), child: Text(isGranted ? '활성화됨' : '활성화')),
            ],
          ),
        ),
      ),
    );
  }

  void _disablePerformancePermission() {} // 추가 정의 (기존 코드 유지용)
}
