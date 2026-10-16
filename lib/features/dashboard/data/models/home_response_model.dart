import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/user_profile_type.dart';

class HomeResponseModel {
  const HomeResponseModel({
    required this.success,
    required this.user,
    required this.profileType,
    required this.availableProfileTypes,
    required this.profileCompleted,
  });

  factory HomeResponseModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? const {};
    final role = json['profileType'] as String?;

    return HomeResponseModel(
      success: json['success'] == true,
      user: DashboardUser(
        id: userJson['id']?.toString() ?? '',
        googleId: userJson['googleId']?.toString() ?? '',
        email: userJson['email'] as String? ?? '',
        name: userJson['name'] as String? ?? '',
        picture:
            userJson['profilePicture'] as String? ??
            userJson['picture'] as String?,
      ),
      profileType: UserProfileType.fromString(role),
      availableProfileTypes: (json['roles'] as List<dynamic>? ?? [role])
          .whereType<String>()
          .map(UserProfileType.fromString)
          .toSet()
          .toList(),
      profileCompleted:
          json['profileCompleted'] == true ||
          (role != null && role.toUpperCase() != 'USER'),
    );
  }

  final bool success;
  final DashboardUser user;
  final UserProfileType profileType;
  final List<UserProfileType> availableProfileTypes;
  final bool profileCompleted;
}
