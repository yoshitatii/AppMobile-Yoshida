class User {
  final String username;
  final String password;
  final String role; // 'pemilik_toko' atau 'kasir'
  final String displayName;

  User({
    required this.username,
    required this.password,
    required this.role,
    required this.displayName,
  });
}

// Data user default
class DefaultUsers {
  static final List<User> users = [
    User(
      username: 'pemilik',
      password: 'pemilik123',
      role: 'pemilik_toko',
      displayName: 'Pemilik Toko',
    ),
    User(
      username: 'kasir',
      password: 'kasir123',
      role: 'kasir',
      displayName: 'Kasir',
    ),
  ];

  static User? authenticate(String username, String password) {
    try {
      return users.firstWhere(
        (user) => user.username == username && user.password == password,
      );
    } catch (e) {
      return null;
    }
  }
}
