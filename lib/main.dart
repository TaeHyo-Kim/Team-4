import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      ],
      child: MaterialApp(
        title: '댕댕워킹',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF2ECC71),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }
        // [오류 해결] LoginScreen에서 const 제거
        return LoginScreen();
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

  @override
  Widget build(BuildContext context) {
    // [오류 해결] ProfileScreen을 ProfileView로 정확히 매칭
    final List<Widget> _screens = [
      const PetScreen(),
      const StatisticsScreen(),
      const WalkScreen(),
      const SocialScreen(),
      const ProfileView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Color(0xFFFF9800)),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
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

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("통계"), backgroundColor: const Color(0xFF2ECC71)),
      body: const Center(child: Text("통계 데이터 준비 중")),
    );
  }
}