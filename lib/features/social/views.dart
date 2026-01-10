import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
import '../auth/models.dart';
import '../profile/views.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "검색",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
      onTap: () {
        // [추가] 유저 클릭 시 상세 프로필로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherUserProfileView(user: user),
          ),
        );
      },
    );
  }
}

class OtherUserProfileView extends StatelessWidget {
  final UserModel user;

  const OtherUserProfileView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // SocialViewModel을 통해 팔로우 상태 감지 및 동작 수행
    final socialVM = context.watch<SocialViewModel>();
    final isFollowing = socialVM.isFollowing(user.uid);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${user.nickname}님의 프로필",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. 유저 정보 상단 (이미지, 이름, 팔로우 버튼)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 35, 15, 25),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 45, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.nickname,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(user.bio ?? "안녕하세요!",
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 8),
                      // 통계 정보 (공통 컴포넌트 사용)
                      UserStatsRow(
                        userId: user.uid,
                        postCount: user.stats.postCount,
                        followingCount: user.stats.followingCount,
                        followerCount: user.stats.followerCount,
                      ),
                    ],
                  ),
                ),
                // [변경] 프로필 편집 버튼 대신 팔로우/언팔로우 버튼
                ElevatedButton(
                  onPressed: () => socialVM.toggleFollow(user.uid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey[300] : Colors.amber,
                    foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isFollowing ? "팔로잉" : "팔로우",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(),

          // 2. 해당 유저의 산책 기록 리스트 (필요 시 추가 구현)
          const Expanded(
            child: Center(
              child: Text("기능 준비 중입니다.", style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}