import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'data/repositories.dart';
import 'features/pet/models.dart';
// import 'features/social/models.dart'; // 경로에 맞게 추가 필요

class TestScreen extends StatelessWidget {
  TestScreen({super.key});

  // 레포지토리 인스턴스
  final UserRepository _userRepo = UserRepository();
  final PetRepository _petRepo = PetRepository();
  final WalkRepository _walkRepo = WalkRepository();
  final SocialRepository _socialRepo = SocialRepository();

  String get _randomStr => DateTime.now().millisecondsSinceEpoch.toString().substring(8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔥 통합 기능 테스트 (GeoHash)')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('버튼을 순서대로 눌러 기능을 검증하세요.', textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // 1. 회원가입
              _buildTestButton(context, '1. 회원가입 (Auth + DB)', Colors.blue, () async {
                final nick = 'user_$_randomStr';
                final email = '$nick@test.com';
                await _userRepo.signUpWithTransaction(
                    email: email, password: 'password123', nickname: nick
                );
                return '가입 성공!\n$email';
              }),

              // 2. 위치 업데이트
              _buildTestButton(context, '2. 내 위치 갱신 (서울 시청)', Colors.green, () async {
                await _userRepo.updateMyLocation(37.5665, 126.9780);
                return '위치 갱신 완료!\n(DB users 컬렉션 확인)';
              }),

              // 3. 주변 탐색
              _buildTestButton(context, '3. 주변 1km 유저 찾기', Colors.teal, () async {
                final stream = _userRepo.getNearbyUsersStream(37.5665, 126.9780, 1.0);
                final users = await stream.first;

                String msg = "발견된 유저: ${users.length}명\n";
                for (var doc in users) {
                  msg += "- ${doc.get('nickname')}\n";
                }
                return msg;
              }),

              // 4. 반려동물 추가
              _buildTestButton(context, '4. 반려동물 추가', Colors.orange, () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('로그인 먼저 해주세요.');

                final newPet = PetModel(
                  id: '',
                  ownerId: user.uid,
                  name: '멍멍이_$_randomStr',
                  breed: '말티즈',
                  birthDate: Timestamp.now(),
                  gender: 'M',
                  weight: 3.5,
                  isNeutered: true,
                );
                await _petRepo.addPet(newPet);
                return '반려동물 추가 완료!';
              }),

              // 5. 산책 기록
              _buildTestButton(context, '5. 산책 기록 저장', Colors.purple, () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('로그인 필요');

                final path = [
                  const LatLng(37.5665, 126.9780),
                  const LatLng(37.5668, 126.9785)
                ];

                await _walkRepo.createWalkRecord(
                  userId: user.uid,
                  petIds: ['temp_pet'],
                  path: path,
                  duration: 600,
                  distance: 0.5,
                  memo: '테스트 산책',
                  emoji: 'happy',
                  visibility: 'public',
                );
                return '산책 기록 저장 완료!';
              }),

              // 6. 소셜 팔로우 (수정된 로직)
              _buildTestButton(context, '6. 다른 유저 팔로우 테스트', Colors.redAccent, () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('로그인 필요');

                // 1. 나를 제외한 다른 유저 찾기
                final snapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .limit(10)
                    .get();

                // 내 UID가 아닌 첫 번째 유저 선택
                final targets = snapshot.docs.where((doc) => doc.id != user.uid).toList();

                if (targets.isEmpty) {
                  throw Exception('팔로우할 대상이 없습니다.\n테스트를 위해 다른 계정을 하나 더 가입해주세요!');
                }

                final targetUser = targets.first;
                final targetUid = targetUser.id;
                final targetNick = targetUser.data()['nickname'] ?? 'Unknown';

                // 2. 팔로우 실행
                await _socialRepo.followUser(myUid: user.uid, targetUid: targetUid);
                return '성공! ${user.email}님이 $targetNick($targetUid)님을 팔로우했습니다.';
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton(BuildContext context, String label, Color color, Future<String> Function() action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
        onPressed: () async {
          try {
            final res = await action();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res), backgroundColor: Colors.green));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러: ${e.toString()}"), backgroundColor: Colors.red));
            }
          }
        },
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}