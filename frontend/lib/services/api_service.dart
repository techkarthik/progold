import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tenant_model.dart';
import '../models/company_model.dart';
import '../models/branch_model.dart';
import '../models/user_model.dart';

class ApiService {
  // Automatically detects production Web origin (e.g. https://progold.vercel.app/api)
  // or falls back to http://localhost:5000/api for local testing / desktop.
  static String get defaultBaseUrl {
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty &&
            !origin.startsWith('http://localhost') &&
            !origin.startsWith('http://127.0.0.1')) {
          return '$origin/api';
        }
      } catch (_) {}
    }
    return "http://localhost:5000/api";
  }

  String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  Map<String, String> _headers([String? token]) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Sends 6-digit OTP to user's email
  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim()}),
      );
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network error: Failed to reach backend server ($e)'};
    }
  }

  /// Verifies OTP code entered by user
  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
      );
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network error: Failed to verify OTP ($e)'};
    }
  }

  /// Pre-validates Turso Database URL and Token
  Future<TursoTestResult> testTursoConnection(String tursoUrl, String tursoToken) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/test-turso'),
        headers: _headers(),
        body: jsonEncode({
          'turso_url': tursoUrl.trim(),
          'turso_token': tursoToken.trim(),
        }),
      );
      final data = jsonDecode(res.body);
      return TursoTestResult.fromJson(data);
    } catch (e) {
      return TursoTestResult(
        success: false,
        message: 'Connection failed: Backend unreachable ($e)',
      );
    }
  }

  /// Registers a new multi-tenant account
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String contactNumber,
    required String tursoUrl,
    required String tursoToken,
    required String validFrom,
    required String validTo,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'contact_number': contactNumber.trim(),
          'turso_url': tursoUrl.trim(),
          'turso_token': tursoToken.trim(),
          'valid_from': validFrom,
          'valid_to': validTo,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Registration error: $e'};
    }
  }

  /// Logs in tenant with email & password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Login error: $e'};
    }
  }

  /// Verifies if an email exists globally
  Future<Map<String, dynamic>> verifyEmail(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/verify-email'),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim(),
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Verification error: $e'};
    }
  }

  /// Fetches authenticated tenant profile, role, & user details
  Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/profile'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Updates business profile (name, logo, contact)
  Future<Map<String, dynamic>> updateProfile(
    String token, {
    String? businessName,
    String? businessLogo,
    String? contactNumber,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/profile'),
        headers: _headers(token),
        body: jsonEncode({
          if (businessName != null) 'business_name': businessName,
          if (businessLogo != null) 'business_logo': businessLogo,
          if (contactNumber != null) 'contact_number': contactNumber,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update profile: $e'};
    }
  }

  /// Fetches tables and schemas from tenant's connected Turso DB
  Future<List<TableOverview>> getTenantDbOverview(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/db/overview'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['tables'] is List) {
          return (data['tables'] as List)
              .map((t) => TableOverview.fromJson(t))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Tests latency and status of tenant's private Turso DB
  Future<TursoTestResult> testTenantDbHealth(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/db/health'),
        headers: _headers(token),
      );
      final data = jsonDecode(res.body);
      return TursoTestResult.fromJson(data);
    } catch (e) {
      return TursoTestResult(success: false, message: '$e');
    }
  }

  /// Executes dynamic SQL query on tenant's private Turso DB
  Future<QueryResult> executeTenantQuery(String token, String sql) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/db/query'),
        headers: _headers(token),
        body: jsonEncode({'sql': sql}),
      );
      final data = jsonDecode(res.body);
      return QueryResult.fromJson(data);
    } catch (e) {
      return QueryResult(success: false, message: 'Query execution error: $e');
    }
  }

  /// Reinstalls & Synchronizes the latest ProGold ERP schema into tenant's database
  Future<Map<String, dynamic>> reinstallTenantDatabase(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/db/reinstall'),
        headers: _headers(token),
      );
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reinstall database schema: $e',
      };
    }
  }

  // ================= COMPANY MASTER CRUD =================

  /// Fetches all company records for tenant
  Future<List<Company>> getCompanies(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/companies'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['companies'] is List) {
          return (data['companies'] as List)
              .map((item) => Company.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching companies: $e");
      return [];
    }
  }

  /// Creates a new company record
  Future<Map<String, dynamic>> createCompany(String token, Company company) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/companies'),
        headers: _headers(token),
        body: jsonEncode(company.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create company: $e'};
    }
  }

  /// Updates an existing company record
  Future<Map<String, dynamic>> updateCompany(String token, String companyId, Company company) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/companies/$companyId'),
        headers: _headers(token),
        body: jsonEncode(company.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update company: $e'};
    }
  }

  /// Deletes a company record
  Future<Map<String, dynamic>> deleteCompany(String token, String companyId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/companies/$companyId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete company: $e'};
    }
  }

  // ================= BRANCH MASTER API METHODS =================

  /// Fetches all branch records for the tenant
  Future<List<Branch>> getBranches(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/branches'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['branches'] != null) {
          return (data['branches'] as List)
              .map((item) => Branch.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("getBranches error: $e");
      return [];
    }
  }

  /// Creates a new branch record
  Future<Map<String, dynamic>> createBranch(String token, Branch branch) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/branches'),
        headers: _headers(token),
        body: jsonEncode(branch.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create branch: $e'};
    }
  }

  /// Updates an existing branch record
  Future<Map<String, dynamic>> updateBranch(String token, String branchId, Branch branch) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/branches/$branchId'),
        headers: _headers(token),
        body: jsonEncode(branch.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update branch: $e'};
    }
  }

  /// Deletes a branch record
  Future<Map<String, dynamic>> deleteBranch(String token, String branchId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/branches/$branchId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete branch: $e'};
    }
  }

  // ================= USER MASTER API METHODS =================

  /// Fetches all user accounts for tenant
  Future<List<AppUser>> getUsers(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/users'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['users'] is List) {
          return (data['users'] as List)
              .map((item) => AppUser.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("getUsers error: $e");
      return [];
    }
  }

  /// Creates a new user record with password & menu permissions
  Future<Map<String, dynamic>> createUser(String token, AppUser user, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/users'),
        headers: _headers(token),
        body: jsonEncode(user.toJson(password: password)),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create user: $e'};
    }
  }

  /// Updates an existing user record & menu permissions
  Future<Map<String, dynamic>> updateUser(String token, String userId, AppUser user) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/users/$userId'),
        headers: _headers(token),
        body: jsonEncode(user.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update user: $e'};
    }
  }

  /// Changes a user's password
  Future<Map<String, dynamic>> changeUserPassword(String token, String userId, String newPassword) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/users/$userId/change-password'),
        headers: _headers(token),
        body: jsonEncode({'new_password': newPassword}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to change password: $e'};
    }
  }

  /// Deletes a user record
  Future<Map<String, dynamic>> deleteUser(String token, String userId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/users/$userId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete user: $e'};
    }
  }

  /// Initiates password recovery via Email OTP
  Future<Map<String, dynamic>> recoverUserPassword(String emailOrUserId) async {
    try {
      final isEmail = emailOrUserId.contains('@');
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/users/recover-password'),
        headers: _headers(),
        body: jsonEncode({
          if (isEmail) 'email': emailOrUserId.trim() else 'userid': emailOrUserId.trim(),
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to initiate password recovery: $e'};
    }
  }
}
