import '../../domain/entities/student_profile.dart';

class StudentModel {
  const StudentModel({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    required this.languages,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    final rawLangs = json['languages'] as List<dynamic>? ?? const [];
    final languages = rawLangs.map((value) => value.toString()).toList();

    return StudentModel(
      id: (json['id'] as num?)?.toInt(),
      googleId: json['googleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      languages: languages,
    );
  }

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final List<String> languages;

  StudentProfile toEntity() => StudentProfile(
    id: id,
    googleId: googleId,
    name: name,
    email: email,
    languages: languages,
  );
}
