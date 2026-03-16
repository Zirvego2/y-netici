import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class CourierReportDetailScreen extends StatefulWidget {
  final int courierId;
  final String courierName;
  final DateTime startDate;
  final DateTime endDate;

  const CourierReportDetailScreen({
    super.key,
    required this.courierId,
    required this.courierName,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<CourierReportDetailScreen> createState() => _CourierReportDetailScreenState();
}

class _CourierReportDetailScreenState extends State<CourierReportDetailScreen> {
  int? _bayId;
  bool _isLoading = false;
  
  int _orderCount = 0;
  double _cashAmount = 0.0;
  int _cashCount = 0;
  double _cardAmount = 0.0;
  int _cardCount = 0;
  double _onlineAmount = 0.0;
  int _onlineCount = 0;
  double _totalDistance = 0.0;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // AuthService'den adminData'yı al
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminData = authService.adminData;
      
      if (adminData != null) {
        _bayId = adminData['s_id'] as int?;
        
        if (_bayId != null) {
          await _loadDetailData();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Kurye Detay _initializeData hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDetailData() async {
    if (_bayId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      debugPrint('📊 Kurye ${widget.courierId} detayları yükleniyor...');
      
      // Bu kuryenin teslim edilmiş siparişlerini çek (tarih filtresini client-side'da yapacağız)
      final ordersQuery = await firestore
          .collection('t_orders')
          .where('s_bay', isEqualTo: _bayId)
          .where('s_courier', isEqualTo: widget.courierId)
          .where('s_stat', isEqualTo: 2) // Teslim edilmiş
          .get();

      debugPrint('📦 Toplam ${ordersQuery.docs.length} sipariş bulundu');

      int orderCount = 0;
      double cashAmount = 0.0;
      int cashCount = 0;
      double cardAmount = 0.0;
      int cardCount = 0;
      double onlineAmount = 0.0;
      int onlineCount = 0;
      double totalDistance = 0.0;
      List<Map<String, dynamic>> ordersList = [];

      for (var doc in ordersQuery.docs) {
        final orderData = doc.data();
        
        // Tarih kontrolü - s_cdate kullan (sipariş oluşturma tarihi)
        DateTime? orderDate;
        if (orderData['s_cdate'] != null) {
          orderDate = (orderData['s_cdate'] as Timestamp).toDate();
        } else if (orderData['s_ddate'] != null) {
          orderDate = (orderData['s_ddate'] as Timestamp).toDate();
        }

        if (orderDate == null) {
          continue;
        }

        // Tarih filtresi
        if (orderDate.isBefore(widget.startDate) || orderDate.isAfter(widget.endDate)) {
          continue;
        }

        orderCount++;

        // Ödeme türü
        final paymentType = orderData['s_pay']?['ss_paytype'] as int?;
        final paymentAmountRaw = orderData['s_pay']?['ss_paycount'];
        final paymentAmount = paymentAmountRaw is num 
            ? paymentAmountRaw.toDouble() 
            : (paymentAmountRaw is String ? double.tryParse(paymentAmountRaw) ?? 0.0 : 0.0);

        String paymentTypeName = 'Bilinmiyor';
        if (paymentType == 0) {
          paymentTypeName = 'Nakit';
          cashAmount += paymentAmount;
          cashCount++;
        } else if (paymentType == 1) {
          paymentTypeName = 'Kredi Kartı';
          cardAmount += paymentAmount;
          cardCount++;
        } else if (paymentType == 2) {
          paymentTypeName = 'Online';
          onlineAmount += paymentAmount;
          onlineCount++;
        }

        // Mesafe
        final distanceRaw = orderData['s_dinstance'];
        final distance = distanceRaw is num 
            ? distanceRaw.toDouble() 
            : (distanceRaw is String ? double.tryParse(distanceRaw) ?? 0.0 : 0.0);
        totalDistance += distance;

        // İşletme adı - s_restaurantName field'ından al
        String restaurantName = orderData['s_restaurantName']?.toString() ?? 'Restoran';

        // Müşteri bilgisi - s_customer field'ının Map olduğundan emin ol
        String customerName = 'Müşteri';
        final sCustomer = orderData['s_customer'];
        if (sCustomer is Map<String, dynamic>) {
          customerName = sCustomer['ss_fullname']?.toString() ?? 'Müşteri';
        }

        // Sipariş detayı
        ordersList.add({
          'orderId': doc.id,
          'date': orderDate,
          'paymentType': paymentTypeName,
          'paymentAmount': paymentAmount,
          'distance': distance,
          'restaurantName': restaurantName,
          'customerName': customerName,
        });
      }

      // Tarihe göre sırala (en yeni en üstte)
      ordersList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _orderCount = orderCount;
        _cashAmount = cashAmount;
        _cashCount = cashCount;
        _cardAmount = cardAmount;
        _cardCount = cardCount;
        _onlineAmount = onlineAmount;
        _onlineCount = onlineCount;
        _totalDistance = totalDistance;
        _orders = ordersList;
      });

      debugPrint('📊 Kurye Detay: Filtrelenmiş sipariş: $_orderCount');
    } catch (e) {
      debugPrint('❌ Kurye detayı yüklenirken hata: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['restaurantName'],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order['customerName'],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPaymentTypeColor(order['paymentType']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order['paymentType'],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getPaymentTypeColor(order['paymentType']),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(order['date']),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.route_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${(order['distance'] as double).toStringAsFixed(2)} km',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  '₺${(order['paymentAmount'] as double).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPaymentTypeColor(String type) {
    switch (type) {
      case 'Nakit':
        return Colors.green;
      case 'Kredi Kartı':
        return Colors.blue;
      case 'Online':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courierName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              '${DateFormat('dd/MM/yyyy').format(widget.startDate)} - ${DateFormat('dd/MM/yyyy').format(widget.endDate)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetailData,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Kurye detayları yükleniyor...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lütfen bekleyin',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // İstatistikler
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _buildStatCard(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Sipariş Sayısı',
                          value: '$_orderCount',
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          icon: Icons.route_outlined,
                          title: 'Mesafe',
                          value: '${_totalDistance.toStringAsFixed(1)} km',
                          color: Colors.purple,
                        ),
                        _buildStatCard(
                          icon: Icons.money_outlined,
                          title: 'Nakit',
                          value: '₺${_cashAmount.toStringAsFixed(2)}',
                          subtitle: '$_cashCount sipariş',
                          color: Colors.green,
                        ),
                        _buildStatCard(
                          icon: Icons.credit_card,
                          title: 'Kredi Kartı',
                          value: '₺${_cardAmount.toStringAsFixed(2)}',
                          subtitle: '$_cardCount sipariş',
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          icon: Icons.smartphone_outlined,
                          title: 'Online',
                          value: '₺${_onlineAmount.toStringAsFixed(2)}',
                          subtitle: '$_onlineCount sipariş',
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          icon: Icons.attach_money,
                          title: 'Toplam Tutar',
                          value: '₺${(_cashAmount + _cardAmount + _onlineAmount).toStringAsFixed(2)}',
                          color: Colors.teal,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sipariş Listesi Başlığı
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Siparişler',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_orderCount',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sipariş Listesi
                  if (_orders.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sipariş bulunamadı',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        return _buildOrderItem(_orders[index]);
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
