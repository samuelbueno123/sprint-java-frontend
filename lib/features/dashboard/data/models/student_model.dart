import '../../domain/entities/student_profile.dart';
import 'student_language_model.dart';

class StudentModel {
  const StudentModel({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    this.profilePicture,
    required this.languages,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    final rawLangs = json['languages'] as List<dynamic>? ?? const [];
    final languages = rawLangs
        .whereType<Map<String, dynamic>>()
        .map(StudentLanguageModel.fromJson)
        .toList();

    return StudentModel(
      id: (json['id'] as num?)?.toInt(),
      googleId: json['googleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePicture: json['profilePicture'] as String?,
      languages: languages,
    );
  }

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final String? profilePicture;
  final List<StudentLanguageModel> languages;

  StudentProfile toEntity() => StudentProfile(
    id: id,
    googleId: googleId,
    name: name,
    email: email,
    profilePicture: profilePicture,
    languages: languages.map((l) => l.toEntity()).toList(),
  );
}
