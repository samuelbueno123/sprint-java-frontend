class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.name,
    this.googleId = '',
    this.photoUrl,
  });

  final String id;
  final String email;
  final String name;
  final String googleId;
  final String? photoUrl;
}
