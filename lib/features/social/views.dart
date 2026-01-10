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

  @override
  void initState() {
    super.initState();
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
                    FocusScope.of(context).unfocus();
                  },
                )
                    : null,
              ),
              onChanged: (val) {
                context.read<SocialViewModel>().searchUsers(val);
                setState(() {});
              },
            ),
          ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.block),
            onPressed: () => _showBlockDialog(context, socialVM),
            tooltip: "차단하기",
          ),
        ],
      ),
      body: Column(
        children: [
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
                      UserStatsRow(
                        userId: user.uid,
                        postCount: user.stats.postCount,
                        followingCount: user.stats.followingCount,
                        followerCount: user.stats.followerCount,
                      ),
                    ],
                  ),
                ),
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
          const Expanded(
            child: Center(
              child: Text("기능 준비 중입니다.", style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, SocialViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("사용자 차단"),
        content: Text("${user.nickname}님을 차단하시겠습니까?\n차단하면 검색 결과에 나타나지 않으며 팔로우가 해제됩니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              await vm.toggleBlock(user.uid);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("차단되었습니다.")),
                );
              }
            },
            child: const Text("차단", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialViewModel>().fetchBlockedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final socialVM = context.watch<SocialViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("차단된 계정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: socialVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : socialVM.blockedUserList.isEmpty
              ? const Center(child: Text("차단된 계정이 없습니다.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: socialVM.blockedUserList.length,
                  itemBuilder: (context, index) {
                    final user = socialVM.blockedUserList[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(user.profileImageUrl!)
                            : null,
                        child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: OutlinedButton(
                        onPressed: () => socialVM.unblockUser(user.uid),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text("차단 해제"),
                      ),
                    );
                  },
                ),
    );
  }
}
