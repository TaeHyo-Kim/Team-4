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
import 'features/statistics/views.dart';
import 'features/statistics/viewmodels.dart';

// 전역 NotificationService 인스턴스
final notificationService = NotificationService();

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
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => StatViewModel()),
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

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
    WidgetsBinding.instance.addObserver(this);
    // 사용자가 로그인되어 있을 때 알림 리스너 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 포그라운드로 돌아와도 리스너는 재설정하지 않음
    // NotificationService 내부에서 이미 중복 방지 로직이 있음
  }

  void _setupNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      notificationService.getFCMToken(); // FCM 토큰 갱신
      notificationService.setupNotificationListener(); // 알림 리스너 설정
    }
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