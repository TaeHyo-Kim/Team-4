import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'viewmodels.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, String> _localPetNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatViewModel>().fetchStatistics();
    });
    // 앱 시작 시 이름표 찾기
    _fetchAllPetNames();
  }

  // 이름표 찾기 로직
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

  // [신규] 펫 삭제 및 산책 기록 정리 함수
  Future<void> _deletePet(String petId, String petName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("반려동물 삭제"),
        content: Text("'$petName'을(를) 삭제하시겠습니까?\n관련된 산책 기록도 함께 정리됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("삭제"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final petRef1 = firestore.collection('users').doc(user.uid).collection('pets').doc(petId);
      final petRef2 = firestore.collection('pets').doc(petId);
      batch.delete(petRef1);
      batch.delete(petRef2);

      final walkQuery1 = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('walks')
          .where('petIds', arrayContains: petId)
          .get();

      final walkQuery2 = await firestore
          .collection('walks')
          .where('userId', isEqualTo: user.uid)
          .where('petIds', arrayContains: petId)
          .get();

      final allDocs = [...walkQuery1.docs, ...walkQuery2.docs];

      for (var doc in allDocs) {
        final data = doc.data();
        List<dynamic> petIds = List.from(data['petIds'] ?? []);
        List<dynamic> savedNames = List.from(data['petNames'] ?? []);

        petIds.remove(petId);
        if (savedNames.contains(petName)) savedNames.remove(petName);

        if (petIds.isEmpty) {
          batch.delete(doc.reference);
        } else {
          batch.update(doc.reference, {
            'petIds': petIds,
            'petNames': savedNames,
          });
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제 및 정리 완료")));
        _fetchAllPetNames();
        context.read<StatViewModel>().fetchStatistics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("로그인이 필요합니다.")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("통계", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      // [단계 1] 펫 명부(Pets) 구독
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pets')
            .where('ownerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, petSnapshot) {
          Map<String, String> petMap = {};

          if (petSnapshot.hasData) {
            for (var doc in petSnapshot.data!.docs) {
              final pet = PetModel.fromDocument(doc);
              petMap[pet.id] = pet.name;
            }
          }
          petMap.addAll(_localPetNames);

          // [단계 2] 산책 기록 스트림
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('walks')
                .snapshots(),
            builder: (context, walkSnapshot) {
              if (walkSnapshot.connectionState == ConnectionState.waiting && !walkSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (walkSnapshot.hasError) {
                return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('walks')
                        .where('userId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (ctx, subSnap) {
                      if (subSnap.hasData) {
                        return Consumer<StatViewModel>(
                          builder: (context, vm, child) {
                            return _buildContent(ctx, subSnap.data!.docs, vm, petMap);
                          },
                        );
                      }
                      if (subSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      return const Center(child: SizedBox());
                    }
                );
              }

              final docs = walkSnapshot.data?.docs ?? [];

              return Consumer<StatViewModel>(
                builder: (context, vm, child) {
                  return _buildContent(context, docs, vm, petMap);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<QueryDocumentSnapshot> docs, StatViewModel vm, Map<String, String> petMap) {
    final allRecords = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _mapToWalkRecord(doc.id, data);
    }).toList();

    final stats = _calculateStats(allRecords, vm.isMonthly, petMap);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<StatViewModel>().fetchStatistics();
        await _fetchAllPetNames();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToggleButtons(vm),
              const SizedBox(height: 30),

              // [수정] 평행(정렬) 맞춘 헤더
              _buildSummaryHeader(
                  stats['totalDist'] as double,
                  stats['headerTotalTime'] as int,
                  vm.isMonthly
              ),

              const SizedBox(height: 30),
              _buildBarChart(stats['chartData'] as List<Map<String, dynamic>>, vm.isMonthly),
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
                child: vm.isMonthly
                    ? _buildMonthlyAnalysis(stats)
                    : _buildDailyAnalysis(stats),
              ),

              const SizedBox(height: 30),
              const Divider(thickness: 1, color: Colors.grey),
              const SizedBox(height: 20),

              Text(
                vm.isMonthly ? "이번 달 활동 요약" : "오늘의 활동 요약",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              _buildPetAggregatedList(allRecords, vm.isMonthly, petMap),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // [핵심] 하단 리스트: 펫별 통계
  Widget _buildPetAggregatedList(List<WalkRecord> allRecords, bool isMonthly, Map<String, String> petMap) {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final monthPrefix = "${now.year}-${now.month}";

    Map<String, Map<String, double>> petStats = {};

    for (var r in allRecords) {
      final rDate = r.startTime.toDate().toLocal();
      final rStr = "${rDate.year}-${rDate.month}-${rDate.day}";
      final rMonth = "${rDate.year}-${rDate.month}";

      bool match = isMonthly ? (rMonth == monthPrefix) : (rStr == todayStr);
      if (!match) continue;

      List<String> ids = [];
      if (r.petIds.isNotEmpty) {
        for (var id in r.petIds) {
          if (petMap.containsKey(id)) {
            ids.add(id);
          }
        }
      } else if (r.savedPetNames.isNotEmpty) {
        ids = r.savedPetNames;
      } else {
        ids = ["unknown"];
      }

      for (var id in ids) {
        if (!petStats.containsKey(id)) {
          petStats[id] = {'duration': 0.0, 'distance': 0.0, 'count': 0.0};
        }
        petStats[id]!['duration'] = (petStats[id]!['duration'] ?? 0) + r.duration;
        petStats[id]!['distance'] = (petStats[id]!['distance'] ?? 0) + r.distance;
        petStats[id]!['count'] = (petStats[id]!['count'] ?? 0) + 1;
      }
    }

    if (petStats.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
            isMonthly ? "이번 달 산책 기록이 없습니다." : "오늘 산책 기록이 없습니다.",
            style: const TextStyle(color: Colors.grey)
        ),
      ));
    }

    final sorted = petStats.entries.toList()
      ..sort((a, b) => b.value['duration']!.compareTo(a.value['duration']!));

    return Column(
      children: sorted.map((entry) {
        final id = entry.key;
        String displayName = petMap[id] ?? id;
        if (id == "unknown") displayName = "혼자 산책";

        return _buildPetStatItem(
            id,
            displayName,
            entry.value['count']!.toInt(),
            entry.value['duration']!.toInt(),
            entry.value['distance']!
        );
      }).toList(),
    );
  }

  Widget _buildPetStatItem(String petId, String name, int count, int seconds, double distance) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    String timeStr = "";
    if (hours > 0) timeStr += "$hours시간 ";
    timeStr += "$minutes분";

    return InkWell(
      onLongPress: () {
        if (petId != "unknown" && !petId.startsWith("이름 미정")) {
          _deletePet(petId, name);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("총 $count회 산책", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                Text("${distance.toStringAsFixed(1)}km", style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- 헬퍼 ---
  WalkRecord _mapToWalkRecord(String id, Map<String, dynamic> data) {
    Timestamp parseTimestamp(dynamic val) {
      if (val is Timestamp) return val;
      return Timestamp.now();
    }
    return WalkRecord(
      id: id,
      startTime: parseTimestamp(data['startTime']),
      endTime: parseTimestamp(data['endTime']),
      duration: (data['duration'] as num?)?.toInt() ?? 0,
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      petIds: List<String>.from(data['petIds'] ?? []),
      savedPetNames: List<String>.from(data['petNames'] ?? []),
      emoji: data['emoji'] as String? ?? '🐕',
    );
  }

  Map<String, dynamic> _calculateStats(List<WalkRecord> records, bool isMonthly, Map<String, String> petMap) {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final monthPrefix = "${now.year}-${now.month}";

    double totalDist = 0.0;
    int headerTotalTime = 0;
    List<Map<String, dynamic>> chartData = [];

    // 그래프 및 상단 총계 계산
    if (!isMonthly) {
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dStr = "${day.year}-${day.month}-${day.day}";
        double dTotal = 0;
        int dTime = 0;
        for (var r in records) {
          final rDate = r.startTime.toDate().toLocal();
          final rStr = "${rDate.year}-${rDate.month}-${rDate.day}";
          if (rStr == dStr) {
            dTotal += r.distance;
            dTime += r.duration;
          }
        }
        chartData.add({'label': "${day.day}일", 'value': dTotal, 'isToday': i == 0});
        if (i == 0) {
          totalDist = dTotal;
          headerTotalTime = dTime;
        }
      }
    } else {
      for (int i = 1; i <= 12; i++) {
        double mTotal = 0;
        int mTime = 0;
        for (var r in records) {
          final rDate = r.startTime.toDate().toLocal();
          if (rDate.year == now.year && rDate.month == i) {
            mTotal += r.distance;
            mTime += r.duration;
          }
        }
        chartData.add({'label': "$i월", 'value': mTotal, 'isToday': i == now.month});
        if (i == now.month) {
          totalDist = mTotal;
          headerTotalTime = mTime;
        }
      }
    }

    // 분석 데이터
    final yesterday = now.subtract(const Duration(days: 1));
    final yStr = "${yesterday.year}-${yesterday.month}-${yesterday.day}";
    double yesterdayDist = 0;
    int totalSeconds = 0;
    Set<String> activeDates = {};
    Map<String, int> petCounts = {};
    Map<String, Map<String, dynamic>> petStats = {};

    for (var r in records) {
      final rDate = r.startTime.toDate().toLocal();
      final rStr = "${rDate.year}-${rDate.month}-${rDate.day}";
      final rMonthStr = "${rDate.year}-${rDate.month}";

      if (rStr == yStr) yesterdayDist += r.distance;

      bool isMatch = isMonthly ? (rMonthStr == monthPrefix) : (rStr == todayStr);

      if (isMatch) {
        if (isMonthly) {
          totalSeconds += r.duration;
          activeDates.add(rStr);
        }

        List<String> names = [];
        if (r.petIds.isNotEmpty) {
          for (var id in r.petIds) {
            if (petMap.containsKey(id)) {
              names.add(petMap[id]!);
            }
          }
          if (names.isEmpty && r.savedPetNames.isNotEmpty) names = r.savedPetNames;
        } else if (r.savedPetNames.isNotEmpty) {
          names = r.savedPetNames;
        } else {
          names = ["혼자 산책"];
        }

        for (var name in names) {
          petCounts[name] = (petCounts[name] ?? 0) + 1;
          if (!petStats.containsKey(name)) {
            petStats[name] = {'dist': 0.0, 'time': 0};
          }
          petStats[name]!['dist'] += r.distance;
          petStats[name]!['time'] += r.duration;
        }
      }
    }

    return {
      'totalDist': totalDist,
      'headerTotalTime': headerTotalTime,
      'chartData': chartData,
      'yesterdayDist': yesterdayDist,
      'petCounts': petCounts,
      'petStats': petStats,
      'totalSeconds': totalSeconds,
      'activeDays': activeDates.length,
      'totalDays': now.day,
    };
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

  // [수정] 평행(수직 정렬) 맞춤
  Widget _buildSummaryHeader(double totalDist, int totalSeconds, bool isMonthly) {
    final label = isMonthly ? "이번 달 활동" : "오늘 활동";

    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    String timeStr = "$m분";
    if (h > 0) timeStr = "$h시간 $m분";

    return Column(
      children: [
        // Row의 수직 정렬(crossAxisAlignment)을 center로 설정하여 구분선을 중앙에 배치
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 거리 그룹
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                    totalDist.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))
                ),
                const SizedBox(width: 4),
                const Text("km", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),

            const SizedBox(width: 25),
            Container(width: 1, height: 40, color: Colors.grey.shade300), // 구분선
            const SizedBox(width: 25),

            // 시간 그룹
            // 시간 텍스트가 40폰트보다 작으므로(32), 시각적 균형을 위해 baseline 대신 center나 별도 처리
            // 여기서는 Text 자체를 배치
            Text(
                timeStr,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> data, bool isMonthly) {
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
            if (item['value'] > 0)
              Text((item['value'] as double).toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              width: isMonthly ? 8 : 14,
              height: height > 4 ? height : 4,
              decoration: BoxDecoration(
                color: item['isToday'] ? const Color(0xFF4CAF50) : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(item['label'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        );
      }).toList(),
    );

    if (isMonthly) {
      return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              width: data.length * 40.0,
              height: 200,
              child: chart
          )
      );
    }
    return SizedBox(height: 200, child: chart);
  }

  Widget _buildDailyAnalysis(Map<String, dynamic> stats) {
    final diffText = stats['totalDist'] > stats['yesterdayDist']
        ? "어제보다 ${(stats['totalDist'] - stats['yesterdayDist']).toStringAsFixed(1)}km 많이 산책했습니다."
        : "어제보다 ${(stats['yesterdayDist'] - stats['totalDist']).toStringAsFixed(1)}km 적게 산책했습니다.";

    final counts = stats['petCounts'] as Map<String, int>;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(diffText, style: const TextStyle(fontSize: 16, height: 1.5)),
      const Divider(height: 30),
      if (counts.isEmpty) const Text("기록이 없습니다.", style: TextStyle(color: Colors.grey)),
      ...counts.entries.map((e) => Text("${e.key}와 ${e.value}회 산책했습니다.", style: const TextStyle(fontSize: 16, height: 1.5))),
    ]);
  }

  Widget _buildMonthlyAnalysis(Map<String, dynamic> stats) {
    final totalSeconds = stats['totalSeconds'] as int;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;

    final petStats = stats['petStats'] as Map<String, Map<String, dynamic>>;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("${stats['totalDays']}일 중 ${stats['activeDays']}일", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text("총 ${(stats['totalDist'] as double).toStringAsFixed(1)}km, 시간: $h:$m", style: const TextStyle(color: Colors.grey)),
      const Divider(height: 30),
      if (petStats.isEmpty) const Text("기록이 없습니다.", style: TextStyle(color: Colors.grey)),
      ...petStats.entries.map((e) {
        final dist = (e.value['dist'] as double).toStringAsFixed(1);
        return Text("${e.key}와 총 ${dist}km 산책했습니다.", style: const TextStyle(fontSize: 16, height: 1.5));
      }),
    ]);
  }
}