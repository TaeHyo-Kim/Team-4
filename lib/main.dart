import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [1] 테마 및 유틸리티
import 'core/theme.dart';

// [2] ViewModels (상태 관리)
import 'features/auth/viewmodels.dart';
import 'features/walk/viewmodels.dart';
import 'features/social/viewmodels.dart';
import 'features/pet/viewmodels.dart';

// [3] Views (화면들)
import 'features/auth/views.dart';   // LoginScreen, ProfileScreen
import 'features/walk/views.dart';   // WalkHomeScreen (산책/지도)
import 'features/social/views.dart'; // SocialScreen (친구찾기)

// import 'firebase_options.dart'; // firebase_options.dart가 있다면 주석 해제

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (options 파일이 있다면 DefaultFirebaseOptions.currentPlatform 추가)
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        // 앱 전체에서 사용할 ViewModel들을 등록합니다.
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        // ChangeNotifierProvider(create: (_) => WalkViewModel()),
        // ChangeNotifierProvider(create: (_) => SocialViewModel()),
        // ChangeNotifierProvider(create: (_) => PetViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '멍멍이 산책', // 앱 이름
      debugShowCheckedModeBanner: false, // 오른쪽 위 'DEBUG' 띠 제거

      // [핵심] 우리가 만든 커스텀 테마 적용
      theme: AppTheme.lightTheme,

      // 앱이 시작되면 AuthGate가 로그인 여부를 판단합니다.
      home: const AuthGate(),
    );
  }
}

/// 로그인 상태를 감지하여 화면을 분기하는 위젯 (Gatekeeper)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. 아직 로딩 중일 때 (잠깐 보임)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. 로그인이 되어 있다면 -> 메인 탭 화면으로 이동
        if (snapshot.hasData) {
          return const MainNavigationScaffold();
        }

        // 3. 로그인이 안 되어 있다면 -> 로그인 화면으로 이동
        return const LoginScreen();
      },
    );
  }
}

/// 하단 탭 네비게이션 (산책 / 커뮤니티 / 내 정보)을 관리하는 메인 화면
class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  // 탭별로 보여줄 화면 리스트
  final List<Widget> _screens = [
    // const WalkHomeScreen(), // 0번 탭: 산책 (지도)
    // const SocialScreen(),   // 1번 탭: 커뮤니티 (친구 찾기)
    // const ProfileScreen(),  // 2번 탭: 내 정보
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 현재 선택된 인덱스의 화면을 보여줌 (상태 유지 위해 IndexedStack 사용 가능)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // 하단 네비게이션 바
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: '산책'
          ),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: '커뮤니티'
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '내 정보'
          ),
        ],
      ),
    );
  }
}