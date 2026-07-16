import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

class CartProvider extends ChangeNotifier {
  final ApiClient apiClient;

  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _locations = [];
  Map<String, dynamic>? _selectedLocation;
  DateTime? _selectedDeliveryDate;
  Map<String, dynamic>? _deliverySchedule;

  // Key: SKU, Value: Quantity
  final Map<String, int> _items = {};
  
  // Key: SKU, Value: Negotiated/calculated price
  final Map<String, double> _prices = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<dynamic> get locations => _locations;
  Map<String, dynamic>? get selectedLocation => _selectedLocation;
  DateTime? get selectedDeliveryDate => _selectedDeliveryDate;
  Map<String, dynamic>? get deliverySchedule => _deliverySchedule;
  Map<String, int> get items => _items;

  CartProvider(this.apiClient);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Fetches shipping location facilities from backend
  Future<void> fetchLocations() async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await apiClient.dio.get('/api/accounts/locations/');
      if (response.statusCode == 200) {
        _locations = response.data;
        
        // Auto-select location from local cache, fallback to first location
        final prefs = await SharedPreferences.getInstance();
        final cachedId = prefs.getInt('selected_location_id');

        if (cachedId != null && _locations.isNotEmpty) {
          final matched = _locations.firstWhere(
            (loc) => loc['id'] == cachedId,
            orElse: () => null,
          );
          if (matched != null) {
            _selectedLocation = matched;
          }
        }

        if (_selectedLocation == null && _locations.isNotEmpty) {
          _selectedLocation = _locations.first;
        }
      }
    } catch (e) {
      _setError(e.toString());
    }

    _setLoading(false);
  }

  // Selects location and caches preference. Clears cart to avoid pricing discrepancies.
  Future<void> selectLocation(Map<String, dynamic> location) async {
    _selectedLocation = location;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_location_id', location['id']);
    
    // Clear cart upon switching branches due to pricing/zip differences
    clearCart();
    notifyListeners();
  }

  // Add/Increment Cart Item
  void addToCart(String sku, double calculatedPrice, int stockLimit) {
    final currentQty = _items[sku] ?? 0;
    if (currentQty < stockLimit) {
      _items[sku] = currentQty + 1;
      _prices[sku] = calculatedPrice;
      notifyListeners();
    }
  }

  // Decrement/Remove Cart Item
  void removeFromCart(String sku) {
    if (!_items.containsKey(sku)) return;
    
    final currentQty = _items[sku]!;
    if (currentQty > 1) {
      _items[sku] = currentQty - 1;
    } else {
      _items.remove(sku);
      _prices.remove(sku);
    }
    notifyListeners();
  }

  // Clears all elements
  void clearCart() {
    _items.clear();
    _prices.clear();
    _selectedDeliveryDate = null;
    _deliverySchedule = null;
    notifyListeners();
  }

  // Calculates subtotal sum locally
  double get subtotal {
    double total = 0.0;
    _items.forEach((sku, quantity) {
      final price = _prices[sku] ?? 0.0;
      total += price * quantity;
    });
    return total;
  }

  double get tax => 0.0; // Dynamic Tax-exempt status for B2B wholesale buyers
  double get total => subtotal;

  // Submits the PO list payload to checkout view
  Future<void> fetchDeliverySchedule(String zipCode) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await apiClient.dio.get(
        '/api/v1/delivery-route/',
        queryParameters: {'zip_code': zipCode},
      );
      if (response.statusCode == 200) {
        _deliverySchedule = response.data;
        if (_deliverySchedule != null && _deliverySchedule!['next_available_date'] != null) {
          _selectedDeliveryDate = DateTime.parse(_deliverySchedule!['next_available_date']);
        }
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  void setSelectedDeliveryDate(DateTime? date) {
    _selectedDeliveryDate = date;
    notifyListeners();
  }

  Future<bool> checkout() async {
    if (_selectedLocation == null) {
      _setError("Invalid checkout parameters. Select a location first.");
      return false;
    }
    if (_selectedDeliveryDate == null) {
      _setError("Please select a scheduled delivery date from the route calendar.");
      return false;
    }

    _setLoading(true);
    _setError(null);

    final dateStr = "${_selectedDeliveryDate!.year.toString().padLeft(4, '0')}-${_selectedDeliveryDate!.month.toString().padLeft(2, '0')}-${_selectedDeliveryDate!.day.toString().padLeft(2, '0')}";
    final payload = {
      "location_id": _selectedLocation!["id"],
      "delivery_date": dateStr,
      "items": _items.entries.map((e) => {"sku": e.key, "quantity": e.value}).toList()
    };

    try {
      final response = await apiClient.dio.post(
        '/api/v1/checkout/',
        data: payload,
      );

      if (response.statusCode == 201) {
        clearCart();
        _setLoading(false);
        return true;
      }
    } catch (e) {
      _setError(_parseCheckoutError(e));
    }

    _setLoading(false);
    return false;
  }

  String _parseCheckoutError(dynamic e) {
    if (e is Exception && e.toString().contains('DioException')) {
      final dioErr = e as dynamic;
      final response = dioErr.response;
      if (response != null && response.data != null) {
        if (response.data is Map && response.data.containsKey('error')) {
          return response.data['error'];
        }
      }
      return dioErr.message ?? "Checkout transmission failed.";
    }
    return e.toString();
  }

  // Adds a new shipping location facility for the authenticated company account
  Future<bool> addLocation({
    required String locationName,
    required String deliveryAddress,
    required String zipCode,
    required String salesTaxId,
  }) async {
    _setLoading(true);
    _setError(null);

    final payload = {
      "location_name": locationName,
      "delivery_address": deliveryAddress,
      "zip_code": zipCode,
      "sales_tax_id": salesTaxId,
    };

    try {
      final response = await apiClient.dio.post(
        '/api/accounts/locations/',
        data: payload,
      );

      if (response.statusCode == 201) {
        await fetchLocations(); // Reload location lists
        _setLoading(false);
        return true;
      }
    } catch (e) {
      if (e.toString().contains('DioException') && (e as dynamic).response != null) {
        final res = (e as dynamic).response;
        if (res.data is Map) {
          final errorMap = res.data as Map;
          final firstKey = errorMap.keys.first;
          final firstVal = errorMap[firstKey];
          _setError("$firstKey: ${firstVal is List ? firstVal.first : firstVal}");
        } else {
          _setError(e.toString());
        }
      } else {
        _setError(e.toString());
      }
    }

    _setLoading(false);
    return false;
  }
}
