import 'package:flutter/material.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import '../domain/login_use_case.dart';

class LoginController with ChangeNotifier {
  LoginUseCase _loginUseCase;
  AuthService authService;

  String email = '';
  String password = '';
  bool isLoading = false;
  String? error;

  LoginController(this._loginUseCase, this.authService);

  // Método para actualizar dependencias
  void updateDependencies(
      LoginUseCase newLoginUseCase, AuthService newAuthService) {
    _loginUseCase = newLoginUseCase;
    authService = newAuthService;
  }

  void setEmail(String value) {
    email = value;
    notifyListeners();
  }

  void setPassword(String value) {
    password = value;
    notifyListeners();
  }

  Future<bool> login() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _loginUseCase.execute(email, password);
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
