import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isGuest = false;
  String? _guestZipCode;
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;
  List<dynamic> _teamMembers = [];

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;
  String? get guestZipCode => _guestZipCode;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userProfile => _userProfile;
  List<dynamic> get teamMembers => _teamMembers;

  AuthProvider(this.apiClient) {
    // Listen to token refresh failures from the api client to force a sign-out
    apiClient.onAuthFailure = logout;
  }

  void loginAsGuest(String zipCode) {
    _isGuest = true;
    _guestZipCode = zipCode;
    _isAuthenticated = false;
    _userProfile = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Pings check-token endpoint at startup to verify cached session keys
  Future<void> checkAuthStatus() async {
    final accessToken = await _storage.read(key: 'access_token');
    if (accessToken == null) {
      _isAuthenticated = false;
      _userProfile = null;
      notifyListeners();
      return;
    }

    try {
      final response = await apiClient.dio.get('/api/accounts/check-token/');
      if (response.statusCode == 200 && response.data['authenticated'] == true) {
        _isAuthenticated = true;
        _userProfile = response.data['user'];
      } else {
        await logout();
      }
    } catch (e) {
      // If server is offline or connection fails, do not force logout if token is valid,
      // but if the token is unauthorized (401 handled by interceptor), we sign out.
      if (e.toString().contains('401')) {
        await logout();
      }
    }
    notifyListeners();
  }

  // Logs in using JWT exchange
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await apiClient.dio.post(
        '/api/accounts/login/',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final accessToken = response.data['access'];
        final refreshToken = response.data['refresh'];
        _userProfile = response.data['user'];

        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);

        _isAuthenticated = true;
        _setLoading(false);
        return true;
      }
    } catch (e) {
      _setError(_parseError(e));
    }
    
    _setLoading(false);
    return false;
  }

  Future<bool> register({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String companyName,
    required String corporateEmail,
    required String locationName,
    required String deliveryAddress,
    required String zipCode,
    required String salesTaxId,
  }) async {
    _setLoading(true);
    _setError(null);

    final payload = {
      "username": username,
      "password": password,
      "email": email,
      "first_name": firstName,
      "last_name": lastName,
      if (phoneNumber != null && phoneNumber.isNotEmpty) "phone_number": phoneNumber,
      "company_name": companyName,
      "corporate_email": corporateEmail,
      "location_data": {
        "location_name": locationName,
        "delivery_address": deliveryAddress,
        "zip_code": zipCode,
        "sales_tax_id": salesTaxId
      }
    };

    try {
      final response = await apiClient.dio.post(
        '/api/accounts/register/',
        data: payload,
      );

      if (response.statusCode == 201) {
        final accessToken = response.data['access'];
        final refreshToken = response.data['refresh'];
        _userProfile = response.data['user'];

        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);

        _isAuthenticated = true;
        _setLoading(false);
        return true;
      }
    } catch (e) {
      _setError(_parseError(e));
    }

    _setLoading(false);
    return false;
  }

  // Requests a cryptographic password reset recovery email link
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await apiClient.dio.post(
        '/api/accounts/password-reset/',
        data: {'email': email},
      );
      _setLoading(false);
      return response.statusCode == 200;
    } catch (e) {
      _setError(_parseError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<void> fetchTeam() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await apiClient.dio.get('/api/accounts/team/');
      if (response.statusCode == 200) {
        _teamMembers = response.data;
      }
    } catch (e) {
      _setError(_parseError(e));
    }
    _setLoading(false);
  }

  Future<bool> addTeamMember({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    required String role,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final payload = {
        "username": username,
        "email": email,
        "password": password,
        "first_name": firstName ?? "",
        "last_name": lastName ?? "",
        "phone_number": phoneNumber ?? "",
        "role": role,
      };
      final response = await apiClient.dio.post(
        '/api/accounts/team/',
        data: payload,
      );
      if (response.statusCode == 201) {
        await fetchTeam(); // Refresh roster list
        _setLoading(false);
        return true;
      }
    } catch (e) {
      _setError(_parseError(e));
    }
    _setLoading(false);
    return false;
  }

  Future<bool> deleteTeamMember(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await apiClient.dio.delete('/api/accounts/team/$id/');
      if (response.statusCode == 200) {
        await fetchTeam(); // Refresh roster list
        _setLoading(false);
        return true;
      }
    } catch (e) {
      _setError(_parseError(e));
    }
    _setLoading(false);
    return false;
  }

  // Clears active sessions and delete secure storage keys
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    _isAuthenticated = false;
    _isGuest = false;
    _guestZipCode = null;
    _userProfile = null;
    _teamMembers = [];
    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e is Exception && e.toString().contains('DioException')) {
      final dioErr = e as dynamic;
      final response = dioErr.response;
      if (response != null && response.data != null) {
        if (response.data is Map) {
          // If serializer validation error occurs, pull the first value
          final errorMap = response.data as Map;
          final firstKey = errorMap.keys.first;
          final firstVal = errorMap[firstKey];
          if (firstVal is List) {
            return "$firstKey: ${firstVal.first}";
          }
          return "$firstKey: $firstVal";
        }
      }
      return dioErr.message ?? "Network connection failed. Please try again.";
    }
    return e.toString();
  }
}
