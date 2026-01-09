import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
import '../pet/views.dart';
import '../../data/repositories.dart';
import '../walk/models.dart';

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
// 3. 내 정보 화면 (ProfileScreen) - 기능트리 4-1. 내 프로필 관리
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<WalkRecordModel> _walkRecords = []; // 산책 기록 리스트
  bool _isLoadingWalks = false;

  @override
  void initState() {
    super.initState();
    _loadWalkRecords();
  }

  // 4-3-1. 친구 산책 기록(피드) 리스트 조회 - 내 산책 기록 가져오기
  Future<void> _loadWalkRecords() async {
    final authVM = context.read<AuthViewModel>();
    final user = authVM.userModel;
    if (user == null) return;

    setState(() {
      _isLoadingWalks = true;
    });

    try {
      final walkRepo = WalkRepository();
      final walks = await walkRepo.getMyWalks(user.uid);
      setState(() {
        _walkRecords = walks;
        _isLoadingWalks = false;
      });
    } catch (e) {
      print("산책 기록 로드 실패: $e");
      setState(() {
        _isLoadingWalks = false;
      });
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
        title: const Text(
          "프로필",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              _showSettingsMenu(context, authVM);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 4-1-1. 내 프로필(닉네임, 한줄소개, 팔로워/팔로잉 수)
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 프로필 사진
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                        ? const Icon(Icons.pets, size: 40, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // 닉네임, 한줄소개, 팔로워/팔로잉
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickname ?? "익명 유저",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.bio ?? "좋은하루 되세요",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "팔로우 ${user?.stats.followingCount ?? 0}",
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              "팔로워 ${user?.stats.followerCount ?? 0}",
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 4-1-2. 내 정보 수정 (닉네임, 한줄 소개)
                  ElevatedButton(
                    onPressed: () {
                      _showEditProfileDialog(context, authVM, user);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("프로필 편집"),
                  ),
                ],
              ),
            ),
            const Divider(),
            // 4-3-1. 친구 산책 기록(피드) 리스트 조회 - 내 산책 기록 그리드
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoadingWalks
                  ? const Center(child: CircularProgressIndicator())
                  : _walkRecords.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text(
                              "아직 산책 기록이 없습니다.",
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _walkRecords.length,
                          itemBuilder: (context, index) {
                            final walk = _walkRecords[index] as WalkRecordModel;
                            // 첫 번째 사진이 있으면 표시, 없으면 기본 아이콘
                            final hasPhoto = walk.photoUrls.isNotEmpty;
                            final photoUrl = hasPhoto ? walk.photoUrls[0] : null;

                            return GestureDetector(
                              onTap: () {
                                // 4-3-2. 친구 기록 상세 보기 (공개 설정된 것만)
                                _showWalkDetail(context, walk);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: photoUrl != null && photoUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(Icons.directions_walk, size: 40, color: Colors.grey);
                                          },
                                        ),
                                      )
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

  // 설정 메뉴 (4-1-3, 4-1-4 포함)
  void _showSettingsMenu(BuildContext context, AuthViewModel authVM) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 4-1-3. 내 위치 공개 설정 (ON/OFF)
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text("내 위치 공개 설정"),
              trailing: Switch(
                value: authVM.userModel?.isLocationPublic ?? false,
                onChanged: (value) {
                  // TODO: 위치 공개 설정 업데이트
                  Navigator.pop(ctx);
                },
                activeColor: const Color(0xFF4CAF50),
              ),
            ),
            // 4-1-4. 차단 사용자 관리
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text("차단 사용자 관리"),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 차단 사용자 관리 화면으로 이동
              },
            ),
            const Divider(),
            // 1-4-1. 로그아웃 (토큰 삭제)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("로그아웃", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _showLogoutDialog(context, authVM);
              },
            ),
            // 1-4-2. 회원 탈퇴
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text("회원 탈퇴", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 회원 탈퇴 다이얼로그
              },
            ),
          ],
        ),
      ),
    );
  }

  // 프로필 편집 다이얼로그 (4-1-2)
  void _showEditProfileDialog(BuildContext context, AuthViewModel authVM, dynamic user) {
    final nicknameCtrl = TextEditingController(text: user?.nickname ?? '');
    final bioCtrl = TextEditingController(text: user?.bio ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("프로필 수정"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameCtrl,
              decoration: const InputDecoration(
                labelText: "닉네임",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioCtrl,
              decoration: const InputDecoration(
                labelText: "한줄소개",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 프로필 수정 로직
              Navigator.pop(ctx);
            },
            child: const Text("수정 완료"),
          ),
        ],
      ),
    );
  }

  // 산책 기록 상세 보기 (4-3-2)
  void _showWalkDetail(BuildContext context, WalkRecordModel walk) {
    final startDate = walk.startTime.toDate();
    final endDate = walk.endTime.toDate();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("산책 기록 - ${startDate.year}.${startDate.month.toString().padLeft(2, '0')}.${startDate.day.toString().padLeft(2, '0')}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("시작 시간: ${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}"),
              Text("종료 시간: ${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}"),
              const SizedBox(height: 8),
              Text("거리: ${walk.distance.toStringAsFixed(2)} km"),
              Text("시간: ${(walk.duration ~/ 60)}분 ${walk.duration % 60}초"),
              if (walk.memo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text("후기: ${walk.memo}"),
              ],
              if (walk.emoji.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text("기분: ${walk.emoji}"),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("닫기"),
          ),
        ],
      ),
    );
  }

  // 로그아웃 다이얼로그 (1-4-1)
  void _showLogoutDialog(BuildContext context, AuthViewModel authVM) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("로그아웃"),
        content: const Text("정말 로그아웃 하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              authVM.logout();
              Navigator.pop(ctx);
            },
            child: const Text("로그아웃", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}