import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
import 'models.dart';

// [1] 펫 목록을 보여주는 위젯
class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final petVM = context.watch<PetViewModel>();

    // 로딩 중이고 데이터가 없을 때
    if (petVM.isLoading && petVM.pets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 펫이 한 마리도 없을 때
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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: petVM.pets.length,
          itemBuilder: (context, index) {
            final pet = petVM.pets[index];
            final isPrimary = pet.isPrimary;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // 대표 펫이면 테두리 강조
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isPrimary
                    ? const BorderSide(color: Colors.amber, width: 2)
                    : BorderSide.none,
              ),
              elevation: isPrimary ? 4 : 1,
              child: ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: isPrimary ? Colors.amber.shade200 : Colors.amber.shade100,
                      backgroundImage: pet.imageUrl.isNotEmpty ? NetworkImage(pet.imageUrl) : null,
                      child: pet.imageUrl.isEmpty
                          ? const Icon(Icons.pets, color: Colors.white)
                          : null,
                    ),
                    // 대표 펫 왕관 아이콘
                    if (isPrimary)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars, color: Colors.amber, size: 16),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("대표", style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                subtitle: Text("${pet.breed} · ${pet.gender == 'M' ? '수컷' : '암컷'}"),

                // 팝업 메뉴 (수정 / 대표 설정 / 삭제)
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      // 수정 화면으로 이동
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PetRegistrationScreen(petToEdit: pet),
                          )
                      );
                    } else if (value == 'primary') {
                      await context.read<PetViewModel>().setPrimaryPet(pet.id);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, pet);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.grey),
                            SizedBox(width: 8),
                            Text("정보 수정"),
                          ],
                        ),
                      ),
                      if (!isPrimary)
                        const PopupMenuItem(
                          value: 'primary',
                          child: Row(
                            children: [
                              Icon(Icons.star_border, color: Colors.amber),
                              SizedBox(width: 8),
                              Text("대표 반려동물 설정"),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text("삭제", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ];
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

  void _showDeleteDialog(BuildContext context, PetModel pet) {
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
  }
}

// [2] 펫 등록 및 정보 수정 화면 (유효성 검사 적용됨)
class PetRegistrationScreen extends StatefulWidget {
  final PetModel? petToEdit; // 수정할 경우 데이터 받기

  const PetRegistrationScreen({super.key, this.petToEdit});

  @override
  State<PetRegistrationScreen> createState() => _PetRegistrationScreenState();
}

class _PetRegistrationScreenState extends State<PetRegistrationScreen> {
  // 1. 폼 상태 관리를 위한 키
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _breedCtrl;
  late TextEditingController _weightCtrl;

  String _gender = 'M';
  bool _isNeutered = false;
  DateTime _birthDate = DateTime.now();

  bool get _isEditMode => widget.petToEdit != null;

  @override
  void initState() {
    super.initState();
    // 데이터 초기화
    if (_isEditMode) {
      final p = widget.petToEdit!;
      _nameCtrl = TextEditingController(text: p.name);
      _breedCtrl = TextEditingController(text: p.breed);
      _weightCtrl = TextEditingController(text: p.weight.toString());
      _gender = p.gender;
      _isNeutered = p.isNeutered;
      _birthDate = p.birthDate.toDate();
    } else {
      _nameCtrl = TextEditingController();
      _breedCtrl = TextEditingController();
      _weightCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

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
    // 2. 유효성 검사 실행 (validator 호출)
    if (!_formKey.currentState!.validate()) {
      return; // 실패 시 중단
    }

    // 키보드 내리기
    FocusScope.of(context).unfocus();

    try {
      if (_isEditMode) {
        // [수정 모드]
        await context.read<PetViewModel>().editPet(
          petId: widget.petToEdit!.id,
          name: _nameCtrl.text.trim(), // 공백 제거
          breed: _breedCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          weight: double.parse(_weightCtrl.text.trim()),
          isNeutered: _isNeutered,
        );
      } else {
        // [등록 모드]
        await context.read<PetViewModel>().addPet(
          name: _nameCtrl.text.trim(),
          breed: _breedCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          weight: double.parse(_weightCtrl.text.trim()),
          isNeutered: _isNeutered,
        );
      }

      if (mounted) Navigator.pop(context); // 화면 닫기
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("작업 실패: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? "정보 수정" : "반려동물 등록"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        // [중요] Form 위젯 사용
        child: Form(
          key: _formKey,
          // 입력 중 실시간 에러 표시
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),

              // [이름] 필수 입력 검사
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: "이름 *",
                  prefixIcon: Icon(Icons.pets),
                  hintText: "이름을 입력해주세요",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "이름을 입력해주세요.";
                  }
                  if (value.trim().length < 2) {
                    return "이름은 2글자 이상이어야 합니다.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // [견종] 필수 입력
              TextFormField(
                controller: _breedCtrl,
                decoration: const InputDecoration(labelText: "견종", prefixIcon: Icon(Icons.category)),
                validator: (v) => (v == null || v.trim().isEmpty) ? "견종을 입력해주세요." : null,
              ),
              const SizedBox(height: 16),

              // [몸무게] 숫자 검사
              TextFormField(
                controller: _weightCtrl,
                decoration: const InputDecoration(labelText: "몸무게 (kg)", prefixIcon: Icon(Icons.monitor_weight)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "몸무게를 입력해주세요.";
                  if (double.tryParse(v) == null) return "숫자만 입력 가능합니다.";
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 성별
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

              // 중성화 여부
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

              // 제출 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isEditMode ? "수정 완료" : "등록 완료"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}