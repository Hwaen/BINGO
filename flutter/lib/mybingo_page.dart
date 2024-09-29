import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class User{
  String gender;
  String acticvitiyLevel;
  String profileImageUrl = 'https://via.placeholder.com/150';
  double recommendedCalories;

  User({
    required this.gender,
    required this.acticvitiyLevel,
    required this.profileImageUrl,
    required this.recommendedCalories,
  });

  Map<String, dynamic> toMap(){
    return <String, dynamic>{
      'gender': gender,
      'acticvitiyLevel': acticvitiyLevel,
      'profileImageUrl': profileImageUrl,
      'recommendedCalories': recommendedCalories,
    };
  }

}

class MybingoPage extends StatefulWidget {
  const MybingoPage({super.key});

  @override
  _MybingoPageState createState() => _MybingoPageState();
}

class _MybingoPageState extends State<MybingoPage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _gender = '';
  String _activityLevel = '앉아서 일하기';
  final _formKey = GlobalKey<FormState>();

  String _profileImageUrl = 'https://via.placeholder.com/150'; // 기본 프로필 사진 URL
  double? _recommendedCalories;

  void _calculateRecommendedCalories() {
    if (_formKey.currentState?.validate() ?? false) {
      final height = double.tryParse(_heightController.text) ?? 0;
      final weight = double.tryParse(_weightController.text) ?? 0;
      final age = int.tryParse(_ageController.text) ?? 0;

      if (height > 0 && weight > 0 && age > 0) {
        double bmr;
        if (_gender == '남성') {
          bmr = 10 * weight + 6.25 * height - 5 * age + 5;
        } else {
          bmr = 10 * weight + 6.25 * height - 5 * age - 161;
        }

        double activityFactor;
        switch (_activityLevel) {
          case '가벼운 활동':
            activityFactor = 1.375;
            break;
          case '보통 활동':
            activityFactor = 1.55;
            break;
          case '활동적인 생활':
            activityFactor = 1.725;
            break;
          case '매우 활동적인 생활':
            activityFactor = 1.9;
            break;
          default:
            activityFactor = 1.2;
        }

        setState(() {
          _recommendedCalories = bmr * activityFactor;
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImageUrl = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                backgroundImage: _profileImageUrl.startsWith('http')
                    ? NetworkImage(_profileImageUrl)
                    : FileImage(File(_profileImageUrl)) as ImageProvider,
                radius: 50,
              ),
            ),
            SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      labelText: '닉네임',
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '닉네임을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '키 (cm)',
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '키를 입력해주세요';
                      }
                      if (double.tryParse(value) == null) {
                        return '유효한 숫자를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '몸무게 (kg)',
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '몸무게를 입력해주세요';
                      }
                      if (double.tryParse(value) == null) {
                        return '유효한 숫자를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '나이 (만)',
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '나이를 입력해주세요';
                      }
                      if (int.tryParse(value) == null) {
                        return '유효한 숫자를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    onChanged: (newValue) {
                      setState(() {
                        _gender = newValue!;
                      });
                    },
                    items: ['남성', '여성']
                        .map((gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            ))
                        .toList(),
                    decoration: InputDecoration(
                      labelText: '성별',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _activityLevel,
                    onChanged: (newValue) {
                      setState(() {
                        _activityLevel = newValue!;
                      });
                    },
                    items:
                        ['앉아서 일하기', '가벼운 활동', '보통 활동', '활동적인 생활', '매우 활동적인 생활']
                            .map((level) => DropdownMenuItem(
                                  value: level,
                                  child: Text(level),
                                ))
                            .toList(),
                    decoration: InputDecoration(
                      labelText: '활동 수준',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _calculateRecommendedCalories,
                    child: Text('칼로리 계산'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (_recommendedCalories != null)
              Text(
                '권장 칼로리: ${_recommendedCalories!.toStringAsFixed(2)} kcal',
                style: TextStyle(fontSize: 18),
              ),
          ],
        ),
      ),
    );
  }
}
