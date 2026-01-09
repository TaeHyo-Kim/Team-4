import 'dart:io'; // 파일 처리를 위해 추가
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'viewmodels.dart';
import 'models.dart';

// [1] 펫 목록을 보여주는 위젯
class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  // 나이 계산 함수
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final petVM = context.watch<PetViewModel>();

    // 로딩 중이고 데이터가 없을 때
    if (petVM.isLoading && petVM.pets.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // 초록색 헤더
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "반려동물",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: petVM.pets.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 48, color: Colors.grey),
            const SizedBox(height: 10),
            const Text("등록된 반려동물이 없습니다."),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PetRegistrationScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
              ),
              child: const Text("반려동물 등록하기"),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          // 펫 리스트
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: petVM.pets.length,
            itemBuilder: (context, index) {
              final pet = petVM.pets[index];
              final isPrimary = pet.isPrimary;
              final age = _calculateAge(pet.birthDate.toDate());

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PetRegistrationScreen(petToEdit: pet),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPrimary ? const Color(0xFFFFD700) : Colors.grey.shade300,
                      width: isPrimary ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 프로필 사진
                      Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                            ),
                            child: pet.imageUrl.isNotEmpty
                                ? ClipOval(
                              child: Image.network(
                                pet.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.pets, color: Colors.grey, size: 40);
                                },
                              ),
                            )
                                : const Icon(Icons.pets, color: Colors.grey, size: 40),
                          ),
                          // 대표 반려동물 별 아이콘 (우측 상단)
                          if (isPrimary)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: Color(0xFFFFD700),
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // 정보 영역
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pet.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isPrimary) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "대표",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFFFD700),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "나이 : ${age}살",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "품종 : ${pet.breed}",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      // 팝업 메뉴 버튼
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PetRegistrationScreen(petToEdit: pet),
                              ),
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
                                    Icon(Icons.star_border, color: Color(0xFFFFD700)),
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
                    ],
                  ),
                ),
              );
            },
          ),
          // 하단 + 버튼
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PetRegistrationScreen()));
              },
              backgroundColor: const Color(0xFFFFD700),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
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

  // 이미지 관련 상태 변수
  File? _imageFile; // 새로 선택한 이미지 파일
  String? _existingImageUrl; // 기존 수정 모드일 때의 이미지 URL
  final ImagePicker _picker = ImagePicker();

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
// 이미지 선택 함수
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // 용량 절약을 위한 압축
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
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
              Navigator.pop(ctx); // 다이얼로그 닫기
              Navigator.pop(context); // 등록 화면 닫기 (목록으로 이동)
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    // 2. 유효성 검사 실행 (validator 호출)
    if (!_formKey.currentState!.validate()) {
      return; // 실패 시 중단
    }

    // 키보드 내리기
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 방지
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("반려동물 정보를 저장 중..."),
          ],
        ),
      ),
    );

    try {
      final petVM = context.read<PetViewModel>();

      // ViewModel에 정의될 함수 호출 (이미지 파일 포함)

      if (_isEditMode) {
        // [수정 모드]
        await petVM.editPet(
          petId: widget.petToEdit!.id,
          name: _nameCtrl.text.trim(), // 공백 제거
          breed: _breedCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          weight: double.parse(_weightCtrl.text.trim()),
          isNeutered: _isNeutered,
          imageFile: _imageFile, // 새 이미지 파일(없으면 null)
        );
      } else {
        // [등록 모드]
        await petVM.addPet(
          name: _nameCtrl.text.trim(),
          breed: _breedCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          weight: double.parse(_weightCtrl.text.trim()),
          isNeutered: _isNeutered,
          imageFile: _imageFile, // 필수 아님 혹은 기본 이미지 처리
        );
      }
// [추가] 2. 성공 시 로딩창 닫고 화면 이동
      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        Navigator.of(context).pop(); // 등록 화면 닫기
      }
    } catch (e) {
      // [추가] 3. 에러 발생 시 로딩창만 닫고 메시지 표시
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("작업 중 오류가 발생했습니다: $e"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 수정 모드일 때 기존 이미지 URL 설정
    if (_isEditMode && widget.petToEdit!.imageUrl.isNotEmpty) {
      _existingImageUrl = widget.petToEdit!.imageUrl;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // 초록색 헤더
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: Text(
          _isEditMode ? "반려동물 상세조회" : "반려동물 등록",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        // [중요] Form 위젯 사용
        child: Form(
          key: _formKey,
          // 입력 중 실시간 에러 표시
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 사진 업로드
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                                border: Border.all(color: Colors.grey.shade300, width: 2),
                              ),
                              child: _imageFile != null
                                  ? ClipOval(
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty
                                  ? ClipOval(
                                child: Image.network(
                                  _existingImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.pets, size: 60, color: Colors.grey);
                                  },
                                ),
                              )
                                  : const Icon(Icons.pets, size: 60, color: Colors.grey)),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF9800),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 24, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "프로필 사진 업로드",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // 필수정보 섹션
              Container(
                color: Colors.grey[50],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "필수정보",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 이름
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "이름 *",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

                    // 품종
                    TextFormField(
                      controller: _breedCtrl,
                      decoration: const InputDecoration(
                        labelText: "품종 *",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "품종을 입력해주세요." : null,
                    ),
                    const SizedBox(height: 16),

                    // 생년월일
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "생년월일 *",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          "${_birthDate.year}년 ${_birthDate.month.toString().padLeft(2, '0')}월 ${_birthDate.day.toString().padLeft(2, '0')}일",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 성별
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "성별 *",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile(
                            title: const Text("수컷"),
                            value: "M",
                            groupValue: _gender,
                            onChanged: (v) => setState(() => _gender = v!),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text("암컷"),
                            value: "F",
                            groupValue: _gender,
                            onChanged: (v) => setState(() => _gender = v!),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 몸무게
                    TextFormField(
                      controller: _weightCtrl,
                      decoration: const InputDecoration(
                        labelText: "몸무게 (kg) *",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "몸무게를 입력해주세요.";
                        if (double.tryParse(v) == null) return "숫자만 입력 가능합니다.";
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // 중성화 여부 (토글 스위치)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "중성화 여부 *",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isNeutered,
                          onChanged: (v) => setState(() => _isNeutered = v),
                          activeColor: const Color(0xFF4CAF50),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 등록/수정 버튼
                    if (_isEditMode) ...[
                      // 수정 모드일 때 수정 및 삭제 버튼
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9800),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("수정"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (widget.petToEdit!.isPrimary) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("대표 반려동물은 삭제할 수 없습니다. 다른 반려동물을 대표로 변경한 후 삭제해주세요."),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                _showDeleteDialogForEdit(context, widget.petToEdit!);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("삭제"),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // 등록 모드일 때 등록 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("등록하기"),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialogForEdit(BuildContext context, PetModel pet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("삭제"),
        content: const Text("정말 해당 페이지 정보를 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              try {
                await context.read<PetViewModel>().deletePet(pet.id);
                if (mounted) {
                  Navigator.pop(ctx); // 다이얼로그 닫기
                  Navigator.pop(context); // 수정 화면 닫기
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("삭제 실패: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
