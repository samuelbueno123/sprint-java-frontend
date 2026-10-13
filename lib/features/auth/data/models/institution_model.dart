class InstitutionModel {
  const InstitutionModel({
    required this.id,
    required this.name,
    this.code,
    this.city,
    this.state,
  });

  final int id;
  final String name;
  final String? code;
  final String? city;
  final String? state;

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    return InstitutionModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  String get locationString {
    final parts = <String>[];
    if (city != null && city!.trim().isNotEmpty) parts.add(city!.trim());
    if (state != null && state!.trim().isNotEmpty) parts.add(state!.trim());
    if (parts.isNotEmpty) return parts.join(' - ');
    if (code != null && code!.trim().isNotEmpty) return code!.trim();
    return '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
