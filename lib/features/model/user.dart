class User {
  final String id;
  final String token;
  final String username;
  final List<String> roles;
  final String role;

  User({
    required this.id,
    required this.token,
    required this.username,
    required this.roles,
    required this.role,
  });
}
