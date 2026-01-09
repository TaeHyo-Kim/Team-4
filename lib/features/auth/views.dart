import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';

// -----------------------------------------------------------------------------
// 1. 로그인 화면 (LoginScreen) - 제공된 코드 스타일
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
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
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
// 2. 비밀번호 찾기 화면 (ForgotPasswordScreen) - 중앙 정렬 및 로고 추가
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
              // 앱 공통 로고
              const Icon(Icons.pets, size: 80, color: Colors.amber),
              const SizedBox(height: 20),
              const Text("댕댕워킹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              if (_step == 1) ...[
                const Text("비밀번호를 잊으셨나요?", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "이메일",
                    hintText: "가입하신 이메일을 입력해주세요.",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _handleReset, 
                    child: const Text("비밀번호 재설정 메일 발송"),
                  ),
                ),
              ] else ...[
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  "'${_emailCtrl.text}'로\n재설정 메일을 보냈습니다.", 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  "메일함의 링크를 통해 비밀번호를 변경한 후\n다시 로그인해주세요.", 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("로그인으로 돌아가기"),
                  ),
                ),
              ],
              const SizedBox(height: 80), // 하단에 여백을 추가하여 전체 내용을 위로 올림
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. 회원가입 화면 (SignUpScreen) - 제공된 코드 스타일
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
              TextFormField(
                controller: _emailCtrl, 
                decoration: const InputDecoration(labelText: "이메일", prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => (v == null || !v.contains('@')) ? '올바른 이메일을 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pwCtrl, 
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: "비밀번호 (6자리 이상)", 
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility), 
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? '비밀번호는 6자리 이상이어야 합니다.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nickCtrl, 
                decoration: const InputDecoration(labelText: "닉네임", prefixIcon: Icon(Icons.person_outline), helperText: "다른 유저에게 표시될 이름입니다."),
                validator: (v) => (v == null || v.length < 2) ? '닉네임은 2글자 이상 입력해주세요.' : null,
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _agreedToTerms, 
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                title: const Text("서비스 이용 및 위치 정보 제공 약관에 동의합니다. (필수)", style: TextStyle(fontSize: 14)),
                activeColor: Colors.amber, 
                controlAffinity: ListTileControlAffinity.leading, 
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, 
                height: 50, 
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSignUp, 
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
