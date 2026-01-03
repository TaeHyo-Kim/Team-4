import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
//
// [1] 우리가 만든 기능들 import
import 'features/auth/viewmodels.dart';
import 'features/auth/views.dart';
import 'features/pet/viewmodels.dart';
import 'features/pet/views.dart';
import 'features/social/viewmodels.dart';
import 'features/social/views.dart';
import 'features/walk/viewmodels.dart';
import 'features/walk/views.dart';

// [중요] flutterfire configure로 생성된 파일이 있다면 import 해야 함
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  // (flutterfire configure를 했다면 options: DefaultFirebaseOptions.currentPlatform 추가 필요)
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // [2] MultiProvider: 모든 ViewModel을 앱 최상단에 등록
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => PetViewModel()),
        ChangeNotifierProvider(create: (_) => SocialViewModel()),
        ChangeNotifierProvider(create: (_) => WalkViewModel()),
      ],
      child: MaterialApp(
        title: '멍멍 산책', // 앱 이름
        theme: ThemeData(
          primarySwatch: Colors.amber, // 앱의 메인 색상 (노랑/주황 계열)
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
        ),
        // [3] AuthGate: 로그인 상태에 따라 첫 화면 결정
        home: const AuthGate(),
      ),
    );
  }
}

/// 로그인 상태를 실시간으로 감지해서 화면을 스위칭하는 위젯
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. 데이터가 들어오는 중일 때 (로딩)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. 로그인이 되어 있다면 -> 메인 화면(탭바)으로
        if (snapshot.hasData) {
          return const MainScreen();
        }

        // 3. 로그인이 안 되어 있다면 -> 로그인 화면으로
        return const LoginScreen();
      },
    );
  }
}

/// 하단 탭바를 가진 메인 화면
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 탭별 화면 리스트
  final List<Widget> _screens = [
    const PetScreen(),   // 0: 펫 관리 (홈)
    const SocialScreen(),// 1: 커뮤니티
    const WalkScreen(),  // 2: 산책
    const ProfileScreen(),   // 3: 내 정보 (아래에 간단히 정의함)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // 상태 유지를 위해 IndexedStack 사용
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pets),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: '커뮤니티',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_walk),
            label: '산책',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}

/// 간단한 내 정보 화면 (로그아웃 기능 포함)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authVM = context.read<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("내 정보")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.amber,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              user?.email ?? "이메일 정보 없음",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("UID: ${user?.uid.substring(0, 6)}***", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // 로그아웃 버튼
            ElevatedButton.icon(
              onPressed: () {
                authVM.logout(); // AuthViewModel의 로그아웃 호출
                // AuthGate가 자동으로 감지하여 로그인 화면으로 보냄
              },
              icon: const Icon(Icons.logout),
              label: const Text("로그아웃"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}