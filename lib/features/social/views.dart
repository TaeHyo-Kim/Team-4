import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
import '../auth/models.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchCtrl = TextEditingController();

  // 화면이 처음 뜰 때 데이터 불러오기 (혹은 생성자에서 호출했으면 생략 가능)
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 최신 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialViewModel>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ViewModel 상태 감지
    final socialVM = context.watch<SocialViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("친구 찾기"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<SocialViewModel>().fetchUsers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // [1] 검색바 영역
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "닉네임 검색",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<SocialViewModel>().searchUsers('');
                    FocusScope.of(context).unfocus(); // 키보드 내리기
                  },
                )
                    : null,
              ),
              onChanged: (val) {
                // 입력할 때마다 검색 실행
                context.read<SocialViewModel>().searchUsers(val);
                setState(() {}); // X버튼 표시 갱신용
              },
            ),
          ),

          // [2] 유저 리스트 영역
          Expanded(
            child: socialVM.isLoading
                ? const Center(child: CircularProgressIndicator())
                : socialVM.users.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.person_off, size: 48, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("검색 결과가 없습니다.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: socialVM.users.length,
              itemBuilder: (context, index) {
                final user = socialVM.users[index];
                return _buildUserTile(context, user, socialVM);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 리스트 아이템 (유저 한 명)
  Widget _buildUserTile(BuildContext context, UserModel user, SocialViewModel vm) {
    final isFollowing = vm.isFollowing(user.uid);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[300],
        backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(
        user.nickname,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      // 이메일이나 상태 메시지 등 보조 정보
      subtitle: Text(
        user.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: ElevatedButton(
        onPressed: () async {
          try {
            await context.read<SocialViewModel>().toggleFollow(user.uid);
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("작업에 실패했습니다.")),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          // 팔로우 중이면 회색, 아니면 노란색(테마색)
          backgroundColor: isFollowing ? Colors.grey[200] : Colors.amber,
          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          isFollowing ? "팔로잉" : "팔로우",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}