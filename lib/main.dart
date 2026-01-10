import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
import 'core/notification_service.dart';

// 백그라운드 메시지 핸들러 (최상위 레벨 함수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('백그라운드 알림 처리: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Firebase Messaging 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // 알림 서비스 초기화
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => PetViewModel()),
        ChangeNotifierProvider(create: (_) => SocialViewModel()),
        ChangeNotifierProvider(create: (_) => WalkViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()), // ProfileViewModel 추가
      ],
      child: MaterialApp(
        title: '댕댕워킹',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: false,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final NotificationService _notificationService = NotificationService();

  // ProfileScreen(옛날버전) 대신 ProfileView(수정된 버전)를 사용
  final List<Widget> _screens = [
    const PetScreen(),   
    const StatisticsScreen(),
    const WalkScreen(),  
    const SocialScreen(),
    const ProfileView(), // ProfileView로 교체
  ];

  @override
  void initState() {
    super.initState();
    // 사용자가 로그인되어 있을 때 알림 리스너 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _notificationService.getFCMToken(); // FCM 토큰 갱신
        _notificationService.setupNotificationListener(); // 알림 리스너 설정
      }
    });
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFF9800), 
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
            NavigationDestination(icon: Icon(Icons.home, color: Colors.white), label: '홈'),
            NavigationDestination(icon: Icon(Icons.bar_chart, color: Colors.white), label: '통계'),
            NavigationDestination(icon: Icon(Icons.directions_walk, color: Colors.white), label: '산책'),
            NavigationDestination(icon: Icon(Icons.search, color: Colors.white), label: '검색'),
            NavigationDestination(icon: Icon(Icons.person, color: Colors.white), label: '프로필'),
          ],
        ),
      ),
    );
  }
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isDaily = true;
  String _selectedType = "거리";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        key: const ValueKey('statistics_appbar'),
        backgroundColor: const Color(0xFF2ECC71),
        title: const Text("통계", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text("${_isDaily ? '일별' : '월별'} 통계 기능은 준비 중입니다.", style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
