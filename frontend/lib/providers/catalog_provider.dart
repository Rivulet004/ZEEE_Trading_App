import 'package:flutter/material.dart';
import '../services/api_client.dart';

class CatalogProvider extends ChangeNotifier {
  final ApiClient apiClient;

  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _products = [];
  List<dynamic> _orderHistory = [];
  List<dynamic> _categories = [];

  int _totalCount = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  final int _pageSize = 20;

  String _searchQuery = '';
  String? _selectedCategorySlug;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<dynamic> get products => _products;
  List<dynamic> get orderHistory => _orderHistory;
  List<dynamic> get categories => _categories;

  int get totalCount => _totalCount;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  String get searchQuery => _searchQuery;
  String? get selectedCategorySlug => _selectedCategorySlug;

  CatalogProvider(this.apiClient);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Updates search text query parameters and triggers a reload
  void updateSearchQuery(String query, int? locationId) {
    _searchQuery = query;
    fetchCatalog(locationId: locationId, refresh: true);
  }

  // Updates category filter slug parameters and triggers a reload
  void updateCategoryFilter(String? slug, int? locationId) {
    _selectedCategorySlug = slug;
    fetchCatalog(locationId: locationId, refresh: true);
  }

  // Queries the backend paginated products list view
  Future<void> fetchCatalog({required int? locationId, bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _products.clear();
    }

    _setLoading(true);
    _setError(null);

    final Map<String, dynamic> params = {
      'page': _currentPage,
      'page_size': _pageSize,
    };

    if (locationId != null) {
      params['location_id'] = locationId;
    }
    if (_searchQuery.isNotEmpty) {
      params['search'] = _searchQuery;
    }
    if (_selectedCategorySlug != null) {
      params['category_slug'] = _selectedCategorySlug;
    }

    try {
      final response = await apiClient.dio.get(
        '/api/v1/products/',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data['results'];
        _totalCount = response.data['count'];
        _totalPages = response.data['total_pages'];

        if (refresh) {
          _products = results;
        } else {
          _products.addAll(results);
        }
      }
    } catch (e) {
      _setError(e.toString());
    }

    _setLoading(false);
  }

  // Increments catalog page and fetches the next batch of items
  Future<void> loadNextPage({required int? locationId}) async {
    if (_currentPage < _totalPages && !_isLoading) {
      _currentPage++;
      await fetchCatalog(locationId: locationId, refresh: false);
    }
  }

  // Fetches historical tenant purchase order logs
  Future<void> fetchOrderHistory() async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await apiClient.dio.get('/api/v1/orders/history/');
      if (response.statusCode == 200) {
        _orderHistory = response.data;
      }
    } catch (e) {
      _setError(e.toString());
    }

    _setLoading(false);
  }

  // Fetches categories dynamically from database
  Future<void> fetchCategories() async {
    try {
      final response = await apiClient.dio.get('/api/v1/categories/');
      if (response.statusCode == 200) {
        _categories = response.data;
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }
}
