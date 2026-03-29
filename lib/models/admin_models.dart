class ManageUser {
  const ManageUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.lastActiveAt,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? lastActiveAt;

  factory ManageUser.fromJson(Map<String, dynamic> json) {
    return ManageUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'player',
      lastActiveAt: json['lastActiveAt'] as String?,
    );
  }
}
