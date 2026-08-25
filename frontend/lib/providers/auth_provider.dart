import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tenant_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  Tenant? _currentTenant;
  String? _authToken;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // OTP State
  bool _otpSent = false;
  bool _otpVerified = false;
  int _otpCountdown = 0;
  Timer? _countdownTimer;
  String? _devOtpCode;

  // Turso Pre-test State
  bool _isTestingTurso = false;
  TursoTestResult? _tursoTestResult;

  // Database Management State
  List<TableOverview> _tenantTables = [];
  bool _isLoadingTables = false;
  bool _isReinstallingDb = false;
  TursoTestResult? _tenantDbHealth;

  // Verification-First Login State
  String? _userRole; // "ADMIN" or "USER"
  AppUser? _currentUser; // populated if role is USER
  String? _verifiedEmail;
  String? _verifiedEmailUsername;
  String? _verifiedEmailRole;
  bool _isEmailVerifiedForLogin = false;

  // Getters
  Tenant? get currentTenant => _currentTenant;
  String? get authToken => _authToken;
  bool get isAuthenticated => _authToken != null && _currentTenant != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get otpSent => _otpSent;
  bool get otpVerified => _otpVerified;
  int get otpCountdown => _otpCountdown;
  String? get devOtpCode => _devOtpCode;

  bool get isTestingTurso => _isTestingTurso;
  TursoTestResult? get tursoTestResult => _tursoTestResult;

  List<TableOverview> get tenantTables => _tenantTables;
  bool get isLoadingTables => _isLoadingTables;
  bool get isReinstallingDb => _isReinstallingDb;
  TursoTestResult? get tenantDbHealth => _tenantDbHealth;

  String? get userRole => _userRole;
  AppUser? get currentUser => _currentUser;
  String? get verifiedEmail => _verifiedEmail;
  String? get verifiedEmailUsername => _verifiedEmailUsername;
  String? get verifiedEmailRole => _verifiedEmailRole;
  bool get isEmailVerifiedForLogin => _isEmailVerifiedForLogin;
  bool get isAdmin => _userRole == 'ADMIN';

  AuthProvider() {
    _loadSavedSession();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Load session from SharedPreferences
  Future<void> _loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    if (_authToken != null) {
      final profileData = await _api.getProfile(_authToken!);
      if (profileData != null && profileData['tenant'] != null) {
        _currentTenant = Tenant.fromJson(profileData['tenant']);
        _userRole = profileData['role'] ?? 'ADMIN';
        if (profileData['user'] != null && _userRole == 'USER') {
          _currentUser = AppUser.fromJson(profileData['user']);
        } else {
          _currentUser = null;
        }
        fetchTenantDbOverview();
      } else {
        _authToken = null;
        _currentTenant = null;
        _userRole = null;
        _currentUser = null;
        await prefs.remove('auth_token');
      }
      notifyListeners();
    }
  }

  /// Request OTP for registration
  Future<bool> sendOtp(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final res = await _api.sendOtp(email);
    _isLoading = false;

    if (res['success'] == true) {
      _otpSent = true;
      _otpVerified = false;
      _devOtpCode = res['devOtp'];
      _successMessage = res['message'] ?? "OTP sent to $email";
      _startCountdown(60);
      notifyListeners();
      return true;
    } else {
      _errorMessage = res['message'] ?? "Failed to send OTP.";
      notifyListeners();
      return false;
    }
  }

  /// Verify entered OTP
  Future<bool> verifyOtp(String email, String code) async {
    if (code.length < 6) {
      _errorMessage = "Please enter the complete 6-digit OTP.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.verifyOtp(email, code);
    _isLoading = false;

    if (res['success'] == true) {
      _otpVerified = true;
      _successMessage = "Email verified successfully! You can now proceed to register.";
      notifyListeners();
      return true;
    } else {
      _errorMessage = res['message'] ?? "Invalid or expired OTP.";
      notifyListeners();
      return false;
    }
  }

  void _startCountdown(int seconds) {
    _otpCountdown = seconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        _otpCountdown--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  /// Test Turso Connection before Registering
  Future<void> testTursoConnection(String url, String token) async {
    if (url.isEmpty || token.isEmpty) {
      _errorMessage = "Please provide both Turso Database URL and Auth Token.";
      notifyListeners();
      return;
    }

    _isTestingTurso = true;
    _tursoTestResult = null;
    _errorMessage = null;
    notifyListeners();

    final result = await _api.testTursoConnection(url, token);
    _isTestingTurso = false;
    _tursoTestResult = result;
    if (!result.success) {
      _errorMessage = result.message;
    }
    notifyListeners();
  }

  /// Register Tenant
  Future<bool> registerTenant({
    required String email,
    required String password,
    required String contactNumber,
    required String tursoUrl,
    required String tursoToken,
    required String validFrom,
    required String validTo,
  }) async {
    if (!_otpVerified) {
      _errorMessage = "Please verify your email with OTP first.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final res = await _api.register(
      email: email,
      password: password,
      contactNumber: contactNumber,
      tursoUrl: tursoUrl,
      tursoToken: tursoToken,
      validFrom: validFrom,
      validTo: validTo,
    );

    _isLoading = false;

    if (res['success'] == true) {
      _authToken = res['token'];
      if (res['tenant'] != null) {
        _currentTenant = Tenant.fromJson(res['tenant']);
      }
      final prefs = await SharedPreferences.getInstance();
      if (_authToken != null) {
        await prefs.setString('auth_token', _authToken!);
      }
      _successMessage = "Registration successful! Welcome to ProGold.";
      fetchTenantDbOverview();
      notifyListeners();
      return true;
    } else {
      _errorMessage = res['message'] ?? "Registration failed.";
      notifyListeners();
      return false;
    }
  }

  /// Login Tenant
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final res = await _api.login(email: email, password: password);
    _isLoading = false;

    if (res['success'] == true) {
      _authToken = res['token'];
      _userRole = res['role'] ?? 'ADMIN';
      if (res['tenant'] != null) {
        _currentTenant = Tenant.fromJson(res['tenant']);
      }
      if (res['user'] != null && _userRole == 'USER') {
        _currentUser = AppUser.fromJson(res['user']);
      } else {
        _currentUser = null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      if (_authToken != null) {
        await prefs.setString('auth_token', _authToken!);
      }
      _successMessage = "Welcome back!";
      fetchTenantDbOverview();
      notifyListeners();
      return true;
    } else {
      _errorMessage = res['message'] ?? "Login failed.";
      notifyListeners();
      return false;
    }
  }

  /// Verify email before prompting for password
  Future<bool> verifyEmailForLogin(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final res = await _api.verifyEmail(email);
    _isLoading = false;

    if (res['success'] == true && res['exists'] == true) {
      _isEmailVerifiedForLogin = true;
      _verifiedEmail = res['email'];
      _verifiedEmailUsername = res['username'];
      _verifiedEmailRole = res['role'];
      _successMessage = "Email verified! Please enter password.";
      notifyListeners();
      return true;
    } else {
      _isEmailVerifiedForLogin = false;
      _verifiedEmail = null;
      _verifiedEmailUsername = null;
      _verifiedEmailRole = null;
      _errorMessage = res['message'] ?? "Email address not found.";
      notifyListeners();
      return false;
    }
  }

  /// Reset the verification-first login state
  void resetLoginVerification() {
    _isEmailVerifiedForLogin = false;
    _verifiedEmail = null;
    _verifiedEmailUsername = null;
    _verifiedEmailRole = null;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Refresh Tenant DB Overview
  Future<void> fetchTenantDbOverview() async {
    if (_authToken == null) return;
    _isLoadingTables = true;
    notifyListeners();

    _tenantTables = await _api.getTenantDbOverview(_authToken!);
    _tenantDbHealth = await _api.testTenantDbHealth(_authToken!);

    _isLoadingTables = false;
    notifyListeners();
  }

  /// Execute dynamic SQL on tenant DB
  Future<QueryResult> executeQuery(String sql) async {
    if (_authToken == null) {
      return QueryResult(success: false, message: "Not authenticated");
    }
    final result = await _api.executeTenantQuery(_authToken!, sql);
    if (result.success) {
      fetchTenantDbOverview(); // Refresh table stats after query
    }
    return result;
  }

  /// Reinstall & Synchronize latest ProGold ERP schema into tenant's private database
  Future<Map<String, dynamic>> reinstallDatabase() async {
    if (_authToken == null) {
      return {'success': false, 'message': 'Not authenticated.'};
    }
    _isReinstallingDb = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final result = await _api.reinstallTenantDatabase(_authToken!);
    _isReinstallingDb = false;

    if (result['success'] == true) {
      _successMessage = result['message'] ?? "Database schema reinstalled successfully!";
      await fetchTenantDbOverview();
    } else {
      _errorMessage = result['message'] ?? "Failed to reinstall database schema.";
    }
    notifyListeners();
    return result;
  }

  /// Update business name, logo, contact
  Future<bool> updateBusinessProfile({
    String? businessName,
    String? businessLogo,
    String? contactNumber,
  }) async {
    if (_authToken == null || _currentTenant == null) return false;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final res = await _api.updateProfile(
      _authToken!,
      businessName: businessName,
      businessLogo: businessLogo,
      contactNumber: contactNumber,
    );

    _isLoading = false;
    if (res['success'] == true) {
      _currentTenant = _currentTenant!.copyWith(
        businessName: businessName,
        businessLogo: businessLogo,
        contactNumber: contactNumber,
      );
      _successMessage = "Business profile updated successfully!";
      notifyListeners();
      return true;
    } else {
      _errorMessage = res['message'] ?? "Failed to update profile.";
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _authToken = null;
    _currentTenant = null;
    _userRole = null;
    _currentUser = null;
    _otpSent = false;
    _otpVerified = false;
    _tursoTestResult = null;
    _tenantTables = [];
    _isEmailVerifiedForLogin = false;
    _verifiedEmail = null;
    _verifiedEmailUsername = null;
    _verifiedEmailRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
