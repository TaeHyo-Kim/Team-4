import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'viewmodels.dart';

// [1] PetModel 클래스: 이름표 정보를 담을 그릇
class PetModel {
  final String id;
  final String ownerId;
  final String name;

  PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
  });

  factory PetModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String owner = data['ownerId'] ?? data['userId'] ?? '';
    return PetModel(
      id: doc.id,
      ownerId: owner,
      name: data['name'] ?? '이름 없음',
    );
  }
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // [2] 펫 이름 명부 (ID : 이름)
  Map<String, String> _localPetNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatViewModel>().fetchStatistics();
    });
    // 앱 시작 시 이름표 찾기 시작
    _fetchAllPetNames();
  }

  // [3] 이름표 찾기
  Future<void> _fetchAllPetNames() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final names = <String, String>{};

    try {
      final q1 = FirebaseFirestore.instance
          .collection('pets')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final q2 = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .get();

      final results = await Future.wait([q1, q2]);

      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          final pet = PetModel.fromDocument(doc);
          names[pet.id] = pet.name;
        }
      }

      if (mounted) {
        setState(() {
          _localPetNames = names;
        });
      }
    } catch (e) {
      print("이름표 찾기 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StatViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("통계", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                vm.fetchStatistics();
                _fetchAllPetNames();
              }
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await vm.fetchStatistics();
          await _fetchAllPetNames();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 통계 분석 (그래프, 멘트)
                _buildAnalysisSection(vm),

                const SizedBox(height: 30),
                const Divider(thickness: 1, color: Colors.grey),
                const SizedBox(height: 20),

                // [수정] 하단 제목 변경: 모드에 따라 텍스트 변경
                Text(
                  vm.isMonthly ? "이번 달 반려동물 활동" : "오늘의 반려동물 활동",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                // [수정] 모드에 따른 필터링이 적용된 리스트
                _buildPetStatsList(vm),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // [수정] 반려동물별 산책 시간 및 거리 집계 위젯 (일별/월별 필터 적용)
  Widget _buildPetStatsList(StatViewModel vm) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("로그인이 필요합니다."));
    }

    // walks 컬렉션을 실시간으로 가져옵니다.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('walks')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text("데이터 오류: ${snapshot.error}", style: const TextStyle(color: Colors.red));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // [데이터 집계 로직]
        // Key: 펫 이름, Value: {duration: 초, distance: km}
        Map<String, Map<String, double>> petStats = {};

        final now = DateTime.now();
        final currentYear = now.year;
        final currentMonth = now.month;
        final currentDay = now.day;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          // 1. 날짜 확인 (일별/월별 모드에 따라 필터링)
          final startTime = (data['startTime'] as Timestamp?)?.toDate();
          if (startTime == null) continue;

          bool isMatch = false;
          if (vm.isMonthly) {
            // 월별 모드: 연도와 월이 같으면 포함
            if (startTime.year == currentYear && startTime.month == currentMonth) {
              isMatch = true;
            }
          } else {
            // 일별 모드: 연, 월, 일이 모두 같아야 포함
            if (startTime.year == currentYear && startTime.month == currentMonth && startTime.day == currentDay) {
              isMatch = true;
            }
          }

          if (!isMatch) continue; // 조건에 안 맞으면 건너뜀

          final duration = (data['duration'] as num?)?.toInt() ?? 0;
          final distance = (data['distance'] as num?)?.toDouble() ?? 0.0;

          List<dynamic> savedNames = data['petNames'] ?? [];
          List<dynamic> petIds = data['petIds'] ?? [];

          // 이번 산책에 참여한 펫 이름 찾기
          Set<String> involvedPets = {};

          if (savedNames.isNotEmpty) {
            for (var name in savedNames) involvedPets.add(name.toString());
          } else if (petIds.isNotEmpty) {
            for (var id in petIds) {
              final idStr = id.toString();
              // 로컬 명부 -> 뷰모델 명부 -> 알 수 없음
              String name = _localPetNames[idStr] ?? vm.petNames[idStr] ?? "알 수 없음";
              involvedPets.add(name);
            }
          }

          // 통계 누적
          for (var name in involvedPets) {
            if (!petStats.containsKey(name)) {
              petStats[name] = {'duration': 0.0, 'distance': 0.0};
            }
            petStats[name]!['duration'] = (petStats[name]!['duration'] ?? 0.0) + duration;
            petStats[name]!['distance'] = (petStats[name]!['distance'] ?? 0.0) + distance;
          }
        }

        if (petStats.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
                vm.isMonthly ? "이번 달 산책 기록이 없습니다." : "오늘 산책 기록이 없습니다.",
                style: const TextStyle(color: Colors.grey)
            ),
          ));
        }

        // 많이 산책한(시간 기준) 순서 정렬
        final sortedEntries = petStats.entries.toList()
          ..sort((a, b) => b.value['duration']!.compareTo(a.value['duration']!));

        // 리스트 그리기
        return Column(
          children: sortedEntries.map((entry) {
            return _buildPetStatItem(
                entry.key,
                entry.value['duration']!.toInt(),
                entry.value['distance']!
            );
          }).toList(),
        );
      },
    );
  }

  // [수정] 집계 아이템 UI (이름 + 총 시간 + 총 거리)
  Widget _buildPetStatItem(String name, int seconds, double distance) {
    // 시간 포맷팅 (00시간 00분)
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    String timeStr = "";
    if (hours > 0) timeStr += "${hours}시간 ";
    timeStr += "${minutes}분";

    // 거리 포맷팅
    String distStr = "${distance.toStringAsFixed(2)}km";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text("🐶", style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  distStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50), fontSize: 16)
              ),
              Text(
                  timeStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 기존 통계 위젯들 (그대로 유지) ---

  Widget _buildAnalysisSection(StatViewModel vm) {
    return Column(
      children: [
        _buildToggleButtons(vm),
        const SizedBox(height: 30),
        _buildSummaryHeader(vm),
        const SizedBox(height: 30),
        _buildBarChart(vm),
        const SizedBox(height: 40),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            vm.isMonthly ? "${DateTime.now().month}월에는?" : "오늘은 어땠나요?",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: vm.isMonthly ? _buildMonthlyAnalysis(vm) : _buildDailyAnalysis(vm),
        ),
      ],
    );
  }

  Widget _buildToggleButtons(StatViewModel vm) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _toggleBtn(vm, "일일 통계", false),
        _toggleBtn(vm, "월별 통계", true),
      ]),
    );
  }

  Widget _toggleBtn(StatViewModel vm, String text, bool isMonth) {
    final selected = vm.isMonthly == isMonth;
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.toggleMode(isMonth),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          child: Center(child: Text(text, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal))),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(StatViewModel vm) {
    final val = vm.isMonthly ? vm.monthlyAnalysis['totalDist'] : vm.dailyAnalysis['todayDist'];
    final label = vm.isMonthly ? "이번 달 총 산책 거리" : "오늘 산책 거리";
    return Column(children: [
      Text("${(val as double).toStringAsFixed(1)}km", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
      Text(label, style: const TextStyle(color: Colors.grey)),
    ]);
  }

  Widget _buildBarChart(StatViewModel vm) {
    final data = vm.chartData;
    if (data.isEmpty) return const SizedBox(height: 150);
    double maxVal = data.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    Widget chart = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: data.map((item) {
        final height = ((item['value'] as double) / maxVal) * 120;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (item['value'] > 0) Text((item['value'] as double).toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              width: vm.isMonthly ? 6 : 12, height: height > 4 ? height : 4,
              decoration: BoxDecoration(color: item['isToday'] ? const Color(0xFF4CAF50) : Colors.grey[300], borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 8),
            Text(item['label'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        );
      }).toList(),
    );

    if (vm.isMonthly) {
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: data.length * 20.0, height: 160, child: chart));
    }
    return SizedBox(height: 160, child: chart);
  }

  Widget _buildDailyAnalysis(StatViewModel vm) {
    final analysis = vm.dailyAnalysis;
    final counts = analysis['petCounts'] as Map<String, int>;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(analysis['diffText'], style: const TextStyle(fontSize: 16, height: 1.5)),
      const Divider(height: 30),
      if (counts.isEmpty) const Text("기록이 없습니다.", style: TextStyle(color: Colors.grey)),
      ...counts.entries.map((e) => Text("${e.key}와 ${e.value}회 산책했습니다.", style: const TextStyle(fontSize: 16, height: 1.5))),
    ]);
  }

  Widget _buildMonthlyAnalysis(StatViewModel vm) {
    final analysis = vm.monthlyAnalysis;
    final stats = analysis['petStats'] as Map<String, Map<String, dynamic>>;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("${analysis['totalDays']}일 중 ${analysis['activeDays']}일", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text("총 ${(analysis['totalDist'] as double).toStringAsFixed(1)}km, 시간: ${analysis['totalTime']}", style: const TextStyle(color: Colors.grey)),
      const Divider(height: 30),
      if (stats.isEmpty) const Text("기록이 없습니다.", style: TextStyle(color: Colors.grey)),
      ...stats.entries.map((e) {
        final dist = (e.value['dist'] as double).toStringAsFixed(1);
        return Text("${e.key}와 총 ${dist}km 산책했습니다.", style: const TextStyle(fontSize: 16, height: 1.5));
      }),
    ]);
  }
}