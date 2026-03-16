import 'package:flutter/foundation.dart';
import '../models/order.dart' as order_model;
import '../services/order_service.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();
  
  List<order_model.Order> _newOrders = [];
  List<order_model.Order> _inTransitOrders = [];
  bool _isLoading = false;
  String? _error;
  int? _selectedBayId;

  List<order_model.Order> get newOrders => _newOrders;
  List<order_model.Order> get inTransitOrders => _inTransitOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedBayId => _selectedBayId;

  // Bay ID'yi ayarla
  void setBayId(int bayId) {
    _selectedBayId = bayId;
    notifyListeners();
  }

  // Yeni siparişler stream'ini dinle
  Stream<List<order_model.Order>> getNewOrdersStream() {
    if (_selectedBayId == null) {
      return Stream.value([]);
    }
    return _orderService.getNewOrdersStream(_selectedBayId!);
  }

  // Yoldaki siparişler stream'ini dinle
  Stream<List<order_model.Order>> getInTransitOrdersStream() {
    if (_selectedBayId == null) {
      return Stream.value([]);
    }
    return _orderService.getInTransitOrdersStream(_selectedBayId!);
  }

  // Siparişleri güncelle
  void updateNewOrders(List<order_model.Order> orders) {
    _newOrders = orders;
    _error = null;
    notifyListeners();
  }

  void updateInTransitOrders(List<order_model.Order> orders) {
    _inTransitOrders = orders;
    _error = null;
    notifyListeners();
  }

  // Hata ayarla
  void setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  // Loading durumunu ayarla
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
