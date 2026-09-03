import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tenant_model.dart';
import '../models/company_model.dart';
import '../models/branch_model.dart';
import '../models/user_model.dart';
import '../models/account_head_model.dart';
import '../models/tax_model.dart';
import '../models/inventory_models.dart';
import '../models/system_control_model.dart';
import '../models/estimate_model.dart';
import '../models/employee_model.dart';
import '../models/rate_model.dart';

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

  /// Fetches comprehensive Database Status including size, available storage balance, quota & table diagnostics
  Future<Map<String, dynamic>> getTenantDbStatus(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/db/status'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch database status: $e'};
    }
  }

  /// Optimizes database storage and updates query statistics
  Future<Map<String, dynamic>> optimizeTenantDb(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/db/optimize'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Optimization error: $e'};
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

  // ================= ACCOUNT HEAD CRUD =================

  /// Fetches all account head records for tenant
  Future<List<AccountHead>> getAccountHeads(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/account-heads'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['accountHeads'] is List) {
          return (data['accountHeads'] as List)
              .map((item) => AccountHead.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching account heads: $e");
      return [];
    }
  }

  /// Creates a new account head record
  Future<Map<String, dynamic>> createAccountHead(String token, AccountHead head) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/account-heads'),
        headers: _headers(token),
        body: jsonEncode(head.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create account head: $e'};
    }
  }

  /// Updates an existing account head record
  Future<Map<String, dynamic>> updateAccountHead(String token, int id, AccountHead head) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/account-heads/$id'),
        headers: _headers(token),
        body: jsonEncode(head.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update account head: $e'};
    }
  }

  /// Deletes an account head record
  Future<Map<String, dynamic>> deleteAccountHead(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/account-heads/$id'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete account head: $e'};
    }
  }

  /// Fetches custom account head options (types & groups)
  Future<Map<String, dynamic>> getAccountHeadOptions(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/account-heads/options'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'success': false, 'options': []};
    } catch (e) {
      debugPrint("Error fetching account head options: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Creates a custom account head option (ACCOUNT_TYPE or FINANCIAL_GROUP)
  Future<Map<String, dynamic>> createAccountHeadOption(String token, String optionType, String optionValue) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/account-heads/options'),
        headers: _headers(token),
        body: jsonEncode({
          'option_type': optionType,
          'option_value': optionValue,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to save option: $e'};
    }
  }

  // ================= TAX MASTER CRUD =================

  /// Fetches all tax master records for tenant
  Future<List<TaxRecord>> getTaxRecords(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/tax-master'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['taxRecords'] is List) {
          return (data['taxRecords'] as List)
              .map((item) => TaxRecord.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching tax records: $e");
      return [];
    }
  }

  /// Creates a new tax master record
  Future<Map<String, dynamic>> createTaxRecord(String token, TaxRecord tax) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/tax-master'),
        headers: _headers(token),
        body: jsonEncode(tax.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create tax master record: $e'};
    }
  }

  /// Updates an existing tax master record
  Future<Map<String, dynamic>> updateTaxRecord(String token, int id, TaxRecord tax) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/tax-master/$id'),
        headers: _headers(token),
        body: jsonEncode(tax.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update tax master record: $e'};
    }
  }

  /// Deletes a tax master record
  Future<Map<String, dynamic>> deleteTaxRecord(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/tax-master/$id'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete tax master record: $e'};
    }
  }

  // ================= METALS CRUD =================

  Future<List<Metal>> getMetals(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/metals'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['metals'] is List) {
          return (data['metals'] as List).map((i) => Metal.fromJson(i)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getMetals: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createMetal(String token, Metal metal) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/metals'),
        headers: _headers(token),
        body: jsonEncode(metal.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateMetal(String token, String metalid, Metal metal) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/metals/$metalid'),
        headers: _headers(token),
        body: jsonEncode(metal.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMetal(String token, String metalid) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/metals/$metalid'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= PURITIES CRUD =================

  Future<List<Purity>> getPurities(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/purities'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['purities'] is List) {
          return (data['purities'] as List).map((i) => Purity.fromJson(i)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getPurities: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createPurity(String token, Purity purity) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/purities'),
        headers: _headers(token),
        body: jsonEncode(purity.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePurity(String token, int purityid, Purity purity) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/purities/$purityid'),
        headers: _headers(token),
        body: jsonEncode(purity.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePurity(String token, int purityid) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/purities/$purityid'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= CATEGORIES CRUD =================

  Future<List<CategoryRecord>> getCategories(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/categories'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['categories'] is List) {
          return (data['categories'] as List).map((i) => CategoryRecord.fromJson(i)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getCategories: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createCategory(String token, CategoryRecord category) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/categories'),
        headers: _headers(token),
        body: jsonEncode(category.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateCategory(String token, int id, CategoryRecord category) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/categories/$id'),
        headers: _headers(token),
        body: jsonEncode(category.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteCategory(String token, int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/categories/$id'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= PRODUCTS CRUD (4th Inventory Master) =================

  /// Fetches products along with last_productid and next_productid metadata
  Future<Map<String, dynamic>> getProductsData(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/products'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['products'] is List) {
          final items = (data['products'] as List).map((i) => ProductRecord.fromJson(i)).toList();
          return {
            'success': true,
            'products': items,
            'last_productid': data['last_productid'] ?? 0,
            'next_productid': data['next_productid'] ?? 1,
            'total_count': data['total_count'] ?? 0,
          };
        }
      }
      return {'success': false, 'products': <ProductRecord>[], 'last_productid': 0, 'next_productid': 1};
    } catch (e) {
      debugPrint("Error getProductsData: $e");
      return {'success': false, 'products': <ProductRecord>[], 'last_productid': 0, 'next_productid': 1};
    }
  }

  Future<List<ProductRecord>> getProducts(String token) async {
    final data = await getProductsData(token);
    return data['products'] as List<ProductRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createProduct(String token, ProductRecord product) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/products'),
        headers: _headers(token),
        body: jsonEncode(product.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProduct(String token, int productid, ProductRecord product) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/products/$productid'),
        headers: _headers(token),
        body: jsonEncode(product.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteProduct(String token, int productid) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/products/$productid'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= SUB-PRODUCTS CRUD (5th Inventory Master) =================

  /// Fetches subproducts along with last_subproductid and next_subproductid metadata
  Future<Map<String, dynamic>> getSubProductsData(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/subproducts'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['subproducts'] is List) {
          final items = (data['subproducts'] as List).map((i) => SubProductRecord.fromJson(i)).toList();
          return {
            'success': true,
            'subproducts': items,
            'last_subproductid': data['last_subproductid'] ?? 0,
            'next_subproductid': data['next_subproductid'] ?? 1,
            'total_count': data['total_count'] ?? 0,
          };
        }
      }
      return {'success': false, 'subproducts': <SubProductRecord>[], 'last_subproductid': 0, 'next_subproductid': 1};
    } catch (e) {
      debugPrint("Error getSubProductsData: $e");
      return {'success': false, 'subproducts': <SubProductRecord>[], 'last_subproductid': 0, 'next_subproductid': 1};
    }
  }

  Future<List<SubProductRecord>> getSubProducts(String token) async {
    final data = await getSubProductsData(token);
    return data['subproducts'] as List<SubProductRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createSubProduct(String token, SubProductRecord subProduct) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/subproducts'),
        headers: _headers(token),
        body: jsonEncode(subProduct.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSubProduct(String token, int subproductid, SubProductRecord subProduct) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/subproducts/$subproductid'),
        headers: _headers(token),
        body: jsonEncode(subProduct.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteSubProduct(String token, int subproductid) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/subproducts/$subproductid'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= STYLES CRUD (6th Master under Inventory) =================

  /// Fetches styles along with last_styleid and next_styleid metadata
  Future<Map<String, dynamic>> getStylesData(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/styles'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['styles'] is List) {
          final items = (data['styles'] as List).map((i) => StyleRecord.fromJson(i)).toList();
          return {
            'success': true,
            'styles': items,
            'last_styleid': data['last_styleid'] ?? 0,
            'next_styleid': data['next_styleid'] ?? 1,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {'success': false, 'styles': <StyleRecord>[], 'last_styleid': 0, 'next_styleid': 1};
    } catch (e) {
      debugPrint("Error getStylesData: $e");
      return {'success': false, 'styles': <StyleRecord>[], 'last_styleid': 0, 'next_styleid': 1};
    }
  }

  Future<List<StyleRecord>> getStyles(String token) async {
    final data = await getStylesData(token);
    return data['styles'] as List<StyleRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createStyle(String token, StyleRecord style) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/styles'),
        headers: _headers(token),
        body: jsonEncode(style.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateStyle(String token, int styleid, StyleRecord style) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/styles/$styleid'),
        headers: _headers(token),
        body: jsonEncode(style.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {'success': res.statusCode == 200, 'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteStyle(String token, int styleid) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/styles/$styleid'), headers: _headers(token));
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {'success': res.statusCode == 200, 'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= SIZES CRUD (7th Master under Inventory) =================

  /// Fetches sizes along with last_sizeid and next_sizeid metadata
  Future<Map<String, dynamic>> getSizesData(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/sizes'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['sizes'] is List) {
          final items = (data['sizes'] as List).map((i) => SizeRecord.fromJson(i)).toList();
          return {
            'success': true,
            'sizes': items,
            'last_sizeid': data['last_sizeid'] ?? 0,
            'next_sizeid': data['next_sizeid'] ?? 1,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {'success': false, 'sizes': <SizeRecord>[], 'last_sizeid': 0, 'next_sizeid': 1};
    } catch (e) {
      debugPrint("Error getSizesData: $e");
      return {'success': false, 'sizes': <SizeRecord>[], 'last_sizeid': 0, 'next_sizeid': 1};
    }
  }

  Future<List<SizeRecord>> getSizes(String token) async {
    final data = await getSizesData(token);
    return data['sizes'] as List<SizeRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createSize(String token, SizeRecord size) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/sizes'),
        headers: _headers(token),
        body: jsonEncode(size.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSize(String token, int sizeid, SizeRecord size) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/sizes/$sizeid'),
        headers: _headers(token),
        body: jsonEncode(size.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {'success': res.statusCode == 200, 'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteSize(String token, int sizeid) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/sizes/$sizeid'), headers: _headers(token));
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {'success': res.statusCode == 200, 'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= SYSTEM CONTROLS CRUD (4th Menu under Settings) =================

  /// Fetches system controls along with last_sno and next_sno metadata
  Future<Map<String, dynamic>> getSystemControlsData(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/system-controls'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['controls'] is List) {
          final items = (data['controls'] as List).map((i) => SystemControlRecord.fromJson(i)).toList();
          return {
            'success': true,
            'controls': items,
            'last_sno': data['last_sno'] ?? 0,
            'next_sno': data['next_sno'] ?? 1,
            'total_count': data['total_count'] ?? 0,
          };
        }
      }
      return {'success': false, 'controls': <SystemControlRecord>[], 'last_sno': 0, 'next_sno': 1};
    } catch (e) {
      debugPrint("Error getSystemControlsData: $e");
      return {'success': false, 'controls': <SystemControlRecord>[], 'last_sno': 0, 'next_sno': 1};
    }
  }

  Future<List<SystemControlRecord>> getSystemControls(String token) async {
    final data = await getSystemControlsData(token);
    return data['controls'] as List<SystemControlRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createSystemControl(String token, SystemControlRecord control) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/system-controls'),
        headers: _headers(token),
        body: jsonEncode(control.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSystemControl(String token, int sno, SystemControlRecord control) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/system-controls/$sno'),
        headers: _headers(token),
        body: jsonEncode(control.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteSystemControl(String token, int sno) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/system-controls/$sno'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= ESTIMATE / QUOTATION CRUD (3rd Main Menu) =================

  /// Fetches estimates with metadata (counts, total value, next estimate no)
  Future<Map<String, dynamic>> getEstimatesData(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/estimates'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['estimates'] is List) {
          final items = (data['estimates'] as List).map((i) => EstimateRecord.fromJson(i)).toList();
          return {
            'success': true,
            'estimates': items,
            'last_estimate_id': data['last_estimate_id'] ?? 0,
            'next_estimate_no': data['next_estimate_no'] ?? 'EST-1001',
            'total_count': data['total_count'] ?? 0,
            'open_count': data['open_count'] ?? 0,
            'total_value': (data['total_value'] as num?)?.toDouble() ?? 0.0,
          };
        }
      }
      return {'success': false, 'estimates': <EstimateRecord>[], 'next_estimate_no': 'EST-1001'};
    } catch (e) {
      debugPrint("Error getEstimatesData: $e");
      return {'success': false, 'estimates': <EstimateRecord>[], 'next_estimate_no': 'EST-1001'};
    }
  }

  Future<List<EstimateRecord>> getEstimates(String token) async {
    final data = await getEstimatesData(token);
    return data['estimates'] as List<EstimateRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createEstimate(String token, EstimateRecord estimate) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/estimates'),
        headers: _headers(token),
        body: jsonEncode(estimate.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateEstimate(String token, int estimateId, EstimateRecord estimate) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/estimates/$estimateId'),
        headers: _headers(token),
        body: jsonEncode(estimate.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteEstimate(String token, int estimateId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/estimates/$estimateId'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= EMPLOYEE MASTER CRUD =================

  /// Fetches employees with metadata (counts, next empid)
  Future<Map<String, dynamic>> getEmployeesData(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/employees'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['employees'] is List) {
          final items = (data['employees'] as List).map((i) => EmployeeRecord.fromJson(i)).toList();
          return {
            'success': true,
            'employees': items,
            'last_empid': data['last_empid'] ?? 0,
            'next_empid': data['next_empid'] ?? 1001,
            'total_count': data['total_count'] ?? items.length,
            'active_count': data['active_count'] ?? 0,
            'inactive_count': data['inactive_count'] ?? 0,
          };
        }
      }
      return {
        'success': false,
        'employees': <EmployeeRecord>[],
        'last_empid': 0,
        'next_empid': 1001,
        'total_count': 0,
        'active_count': 0,
        'inactive_count': 0,
      };
    } catch (e) {
      debugPrint("Error getEmployeesData: $e");
      return {
        'success': false,
        'employees': <EmployeeRecord>[],
        'last_empid': 0,
        'next_empid': 1001,
        'total_count': 0,
        'active_count': 0,
        'inactive_count': 0,
      };
    }
  }

  Future<List<EmployeeRecord>> getEmployees(String token) async {
    final data = await getEmployeesData(token);
    return data['employees'] as List<EmployeeRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createEmployee(String token, EmployeeRecord employee) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/employees'),
        headers: _headers(token),
        body: jsonEncode(employee.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateEmployee(String token, int empid, EmployeeRecord employee) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/employees/$empid'),
        headers: _headers(token),
        body: jsonEncode(employee.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteEmployee(String token, int empid) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/employees/$empid'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= DAILY PURITY RATES & HISTORY CRUD (Sales & Price Master) =================

  /// Fetches latest purity rates and ticker summary (Gold 24K, 22K 916, Silver)
  Future<LatestRatesSummary> getLatestRates(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tenant/rates/latest'), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return LatestRatesSummary.fromJson(data);
        }
      }
      return LatestRatesSummary();
    } catch (e) {
      debugPrint("Error getLatestRates: $e");
      return LatestRatesSummary();
    }
  }

  /// Fetches rates configured for a specific date (or defaults to last known rates)
  Future<Map<String, dynamic>> getRatesByDate(String token, String date) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/rates/by-date?date=${Uri.encodeComponent(date.trim())}'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['rates'] is List) {
          final items = (data['rates'] as List).map((i) => PurityRateItem.fromJson(i)).toList();
          return {
            'success': true,
            'target_date': data['target_date'] ?? date,
            'is_already_saved_for_date': data['is_already_saved_for_date'] ?? false,
            'rates': items,
          };
        }
      }
      return {'success': false, 'rates': <PurityRateItem>[], 'is_already_saved_for_date': false};
    } catch (e) {
      debugPrint("Error getRatesByDate: $e");
      return {'success': false, 'rates': <PurityRateItem>[], 'is_already_saved_for_date': false};
    }
  }

  /// Saves or updates all daily purity rates for a given date in one operation
  Future<Map<String, dynamic>> saveBulkRates(
    String token,
    String ratedate,
    List<PurityRateItem> rates,
  ) async {
    try {
      final payload = {
        'ratedate': ratedate.trim(),
        'rates': rates.map((r) => r.toJson()).toList(),
      };
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/rates/bulk-update'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetches historical rate logs with optional filters
  Future<List<RateHistoryRecord>> getRateHistory(
    String token, {
    String? fromDate,
    String? toDate,
    String? metalId,
    int? purityId,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (fromDate != null && fromDate.isNotEmpty) queryParams['from_date'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) queryParams['to_date'] = toDate;
      if (metalId != null && metalId.isNotEmpty && metalId != 'ALL') queryParams['metalid'] = metalId;
      if (purityId != null && purityId > 0) queryParams['purityid'] = purityId.toString();

      final uri = Uri.parse('$baseUrl/tenant/rates/history').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['history'] is List) {
          return (data['history'] as List).map((i) => RateHistoryRecord.fromJson(i)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getRateHistory: $e");
      return [];
    }
  }

  /// Deletes a specific historical rate record by ID
  Future<Map<String, dynamic>> deleteRateRecord(String token, int rateId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/tenant/rates/$rateId'), headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}


