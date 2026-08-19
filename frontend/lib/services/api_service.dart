import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tenant_model.dart';

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

  /// Fetches authenticated tenant profile & validity days remaining
  Future<Tenant?> getProfile(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/profile'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['tenant'] != null) {
          return Tenant.fromJson(data['tenant']);
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
}
