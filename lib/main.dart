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
import 'features/profile/viewmodels.dart';
import 'features/profile/views.dart';

//안녕
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
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green, // 앱의 메인 색상 (초록색)
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

  // 탭별 화면 리스트 (5개로 변경)
  final List<Widget> _screens = [
    const PetScreen(),   // 0: 펫 관리 (홈)
    const StatisticsScreen(),// 1: 통계 (비어있음)
    const WalkScreen(),  // 2: 산책
    const SocialScreen(),// 3: 검색
    const ProfileScreen(),   // 4: 내 정보
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // 상태 유지를 위해 IndexedStack 사용
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFF9800), // 오렌지색 네비게이션 바
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.white.withOpacity(0.2),
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home, color: Colors.white),
              selectedIcon: Icon(Icons.home, color: Colors.white),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart, color: Colors.white),
              selectedIcon: Icon(Icons.bar_chart, color: Colors.white),
              label: '통계',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_walk, color: Colors.white),
              selectedIcon: Icon(Icons.directions_walk, color: Colors.white),
              label: '산책',
            ),
            NavigationDestination(
              icon: Icon(Icons.search, color: Colors.white),
              selectedIcon: Icon(Icons.search, color: Colors.white),
              label: '검색',
            ),
            NavigationDestination(
              icon: Icon(Icons.person, color: Colors.white),
              selectedIcon: Icon(Icons.person, color: Colors.white),
              label: '프로필',
            ),
          ],
        ),
      ),
    );
  }
}

/// 통계 화면 (아직 구현 안됨)
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isDaily = true; // 일별/월별 토글
  String _selectedType = "거리"; // 거리/시간 선택

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "통계",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 토글 및 선택 영역
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 일별/월별 토글
                Row(
                  children: [
                    const Text("일일 통계", style: TextStyle(fontSize: 14)),
                    Switch(
                      value: _isDaily,
                      onChanged: (value) {
                        setState(() {
                          _isDaily = value;
                        });
                      },
                      activeColor: const Color(0xFF4CAF50),
                    ),
                  ],
                ),
                const Spacer(),
                // 거리/시간 선택
                DropdownButton<String>(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(value: "거리", child: Text("거리")),
                    DropdownMenuItem(value: "시간", child: Text("시간")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          // 그래프 영역 (임시)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    "${_isDaily ? '일별' : '월별'} 통계 기능은 준비 중입니다.",
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ProfileScreen은 features/auth/views.dart에서 import하여 사용합니다.