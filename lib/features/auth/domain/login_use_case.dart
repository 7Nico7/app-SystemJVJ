import '../data/auth_service.dart';

class LoginUseCase {
  final AuthService _authService;

  LoginUseCase(this._authService);

  Future<void> execute(String email, String password) async {
    await _authService.login(email, password);
  }
}
