import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
import 'models.dart';
import '../../core/theme.dart'; // 테마 사용

// [1] 펫 목록을 보여주는 위젯 (다른 화면에 끼워넣기 좋게 만듦)
class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 뷰모델 감지
    final petVM = context.watch<PetViewModel>();

    if (petVM.isLoading && petVM.pets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (petVM.pets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 48, color: Colors.grey),
            const SizedBox(height: 10),
            const Text("등록된 반려동물이 없습니다."),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PetRegistrationScreen()));
              },
              child: const Text("반려동물 등록하기"),
            )
          ],
        ),
      );
    }

    return Column(
      children: [
        // 펫 리스트
        ListView.builder(
          shrinkWrap: true, // 다른 스크롤뷰 안에 들어갈 때 필수
          physics: const NeverScrollableScrollPhysics(),
          itemCount: petVM.pets.length,
          itemBuilder: (context, index) {
            final pet = petVM.pets[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  backgroundImage: pet.imageUrl.isNotEmpty ? NetworkImage(pet.imageUrl) : null,
                  child: pet.imageUrl.isEmpty ? const Icon(Icons.pets, color: Colors.amber) : null,
                ),
                title: Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${pet.breed} · ${pet.gender == 'M' ? '수컷' : '암컷'}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                    // 삭제 확인 다이얼로그
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("삭제"),
                        content: Text("${pet.name} 정보를 삭제하시겠습니까?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
                          TextButton(
                            onPressed: () {
                              context.read<PetViewModel>().deletePet(pet.id);
                              Navigator.pop(ctx);
                            },
                            child: const Text("삭제", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        // 추가 버튼
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PetRegistrationScreen()));
            },
            icon: const Icon(Icons.add),
            label: const Text("반려동물 추가하기"),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ],
    );
  }
}

// [2] 펫 등록 화면
class PetRegistrationScreen extends StatefulWidget {
  const PetRegistrationScreen({super.key});

  @override
  State<PetRegistrationScreen> createState() => _PetRegistrationScreenState();
}

class _PetRegistrationScreenState extends State<PetRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String _gender = 'M';
  bool _isNeutered = false;
  DateTime _birthDate = DateTime.now();

  // 생일 선택 피커
  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<PetViewModel>().addPet(
        name: _nameCtrl.text.trim(),
        breed: _breedCtrl.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        weight: double.parse(_weightCtrl.text.trim()),
        isNeutered: _isNeutered,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("등록 실패: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("반려동물 등록")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [이미지] (지금은 아이콘으로 대체, 추후 이미지 피커 연동)
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),

              // 이름
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "이름", prefixIcon: Icon(Icons.pets)),
                validator: (v) => v!.isEmpty ? "이름을 입력하세요" : null,
              ),
              const SizedBox(height: 16),

              // 견종
              TextFormField(
                controller: _breedCtrl,
                decoration: const InputDecoration(labelText: "견종 (예: 말티즈)", prefixIcon: Icon(Icons.category)),
                validator: (v) => v!.isEmpty ? "견종을 입력하세요" : null,
              ),
              const SizedBox(height: 16),

              // 몸무게
              TextFormField(
                controller: _weightCtrl,
                decoration: const InputDecoration(labelText: "몸무게 (kg)", prefixIcon: Icon(Icons.monitor_weight)),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "몸무게를 입력하세요" : null,
              ),
              const SizedBox(height: 24),

              // 성별 & 중성화 (Row로 배치)
              const Text("성별", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text("수컷"), value: "M", groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text("암컷"), value: "F", groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text("중성화 수술을 했나요?"),
                value: _isNeutered,
                onChanged: (v) => setState(() => _isNeutered = v!),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // 생일
              ListTile(
                title: const Text("생일"),
                subtitle: Text("${_birthDate.year}년 ${_birthDate.month}월 ${_birthDate.day}일"),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              ),
              const SizedBox(height: 32),

              // 등록 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text("등록 완료"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}