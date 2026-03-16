import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zirvego_main_app/services/auth_service.dart';
import 'package:zirvego_main_app/services/order_service.dart';
import 'package:zirvego_main_app/services/work_service.dart';
import 'package:zirvego_main_app/services/courier_service.dart';
import 'package:zirvego_main_app/models/order.dart' as order_model;
import 'package:zirvego_main_app/screens/order_detail_screen.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _orderService = OrderService();
  final WorkService _workService = WorkService();
  final CourierService _courierService = CourierService();
  
  // Filtreler
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedStatus; // 2: Teslim Edildi, 3: İptal Edildi
  int? _selectedWorkId; // İşletme ID
  int? _selectedCourierId; // Kurye ID
  int? _selectedPaymentType; // Ödeme türü
  
  // Veriler
  List<order_model.Order> _orders = [];
  List<Map<String, dynamic>> _works = []; // İşletmeler
  List<Map<String, dynamic>> _couriers = []; // Kuryeler
  bool _isLoading = false;
  bool _isLoadingFilters = false;

  @override
  void initState() {
    super.initState();
    // Varsayılan tarih aralığını bugünün 00:00 - 23:59 olarak ayarla
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _loadFilterData();
    _loadOrders();
  }

  // Filtre verilerini yükle (işletmeler, kuryeler)
  Future<void> _loadFilterData() async {
    setState(() {
      _isLoadingFilters = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminData = authService.adminData;
      final bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;
      final isMainAdmin = adminData?['s_bay'] == null;

      // İşletmeleri yükle
      final firestore = FirebaseFirestore.instance;
      final List<QueryDocumentSnapshot> allWorkDocs = [];
      
      if (isMainAdmin) {
        // Ana admin: s_bay == bayId veya s_id == bayId olan işletmeleri göster
        final worksByBay = await firestore
            .collection('t_work')
            .where('s_bay', isEqualTo: bayId)
            .get();
        
        final worksById = await firestore
            .collection('t_work')
            .where('s_id', isEqualTo: bayId)
            .get();
        
        // İki sonucu birleştir ve tekrarları kaldır
        final docIds = <String>{};
        for (var doc in worksByBay.docs) {
          if (!docIds.contains(doc.id)) {
            allWorkDocs.add(doc);
            docIds.add(doc.id);
          }
        }
        for (var doc in worksById.docs) {
          if (!docIds.contains(doc.id)) {
            allWorkDocs.add(doc);
            docIds.add(doc.id);
          }
        }
      } else {
        // Normal admin: sadece s_bay == bayId olan işletmeleri göster
        final worksSnapshot = await firestore
            .collection('t_work')
            .where('s_bay', isEqualTo: bayId)
            .get();
        allWorkDocs.addAll(worksSnapshot.docs);
      }

      final works = allWorkDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // s_id tipini kontrol et ve düzelt
        dynamic workId = data['s_id'];
        if (workId is String) {
          workId = int.tryParse(workId) ?? 0;
        } else if (workId is! int) {
          workId = 0;
        }
        
        // İşletme adını al (s_name veya ss_name)
        final workName = data['s_name'] ?? data['ss_name'] ?? 'Bilinmiyor';
        
        return {
          'id': workId,
          'name': workName.toString(),
        };
      }).toList();

      // Kuryeleri yükle
      final couriersList = await _courierService.getCouriersByBay(bayId);
      final couriers = couriersList.map((courier) {
        return {
          'id': courier.sId,
          'name': courier.fullName,
        };
      }).toList();

      setState(() {
        _works = works;
        _couriers = couriers;
        _isLoadingFilters = false;
      });
    } catch (e) {
      debugPrint('Filtre verileri yükleme hatası: $e');
      setState(() {
        _isLoadingFilters = false;
      });
    }
  }

  // Siparişleri yükle
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminData = authService.adminData;
      final bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;

      final firestore = FirebaseFirestore.instance;
      Query query = firestore.collection('t_orders');

      // Bay ID filtresi
      query = query.where('s_bay', isEqualTo: bayId);

      // Durum filtresi (2: Teslim Edildi, 3: İptal Edildi)
      if (_selectedStatus != null) {
        query = query.where('s_stat', isEqualTo: _selectedStatus);
      } else {
        // Varsayılan: Teslim edilen ve iptal edilen
        query = query.where('s_stat', whereIn: [2, 3]);
      }

      // Tarih filtresi (varsayılan: bugün)
      final startTimestamp = Timestamp.fromDate(
        _startDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0),
      );
      query = query.where('s_cdate', isGreaterThanOrEqualTo: startTimestamp);

      final endTimestamp = Timestamp.fromDate(
        _endDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
      );
      query = query.where('s_cdate', isLessThanOrEqualTo: endTimestamp);

      // İşletme filtresi
      if (_selectedWorkId != null) {
        query = query.where('s_work', isEqualTo: _selectedWorkId);
      }

      // Kurye filtresi
      if (_selectedCourierId != null) {
        query = query.where('s_courier', isEqualTo: _selectedCourierId);
      }

      // Sıralama
      query = query.orderBy('s_cdate', descending: true).limit(100);

      final snapshot = await query.get();

      // Siparişleri işle
      final orders = <order_model.Order>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Ödeme türü filtresi (client-side)
          if (_selectedPaymentType != null) {
            final payData = data['s_pay'] as Map<String, dynamic>?;
            final payType = payData?['ss_paytype'] as int?;
            if (payType != _selectedPaymentType) {
              continue; // Bu siparişi atla
            }
          }
          
          final workId = data['s_work'] ?? 0;
          final courierId = data['s_courier'] ?? 0;

          final workInfo = workId > 0 ? await _workService.getWorkInfo(workId) : null;
          final courierInfo = courierId > 0 ? await _courierService.getCourierInfo(courierId) : null;

          final order = order_model.Order.fromFirestore(
            doc,
            workInfo: workInfo,
            courierInfo: courierInfo,
            bayInfo: null,
          );
          orders.add(order);
        } catch (e) {
          debugPrint('Sipariş parse hatası: $e');
        }
      }

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Sipariş yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Tarih seçici
  Future<void> _selectDate(bool isStartDate) async {
    final now = DateTime.now();
    final initialDate = isStartDate 
        ? (_startDate ?? DateTime(now.year, now.month, now.day))
        : (_endDate ?? DateTime(now.year, now.month, now.day));
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        } else {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Siparişler',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Filtreler
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Başlangıç Tarihi
                  _buildFilterChip(
                    label: 'Başlangıç Tarihi',
                    value: _startDate != null
                        ? DateFormat('dd.MM.yyyy HH:mm').format(_startDate!)
                        : 'Seç',
                    onTap: () => _selectDate(true),
                  ),
                  const SizedBox(width: 8),
                  // Bitiş Tarihi
                  _buildFilterChip(
                    label: 'Bitiş Tarihi',
                    value: _endDate != null
                        ? DateFormat('dd.MM.yyyy HH:mm').format(_endDate!)
                        : 'Seç',
                    onTap: () => _selectDate(false),
                  ),
                  const SizedBox(width: 8),
                  // Durum
                  _buildStatusFilter(),
                  const SizedBox(width: 8),
                  // İşletme Seçimi
                  _buildWorkFilter(),
                  const SizedBox(width: 8),
                  // Kurye Seçimi
                  _buildCourierFilter(),
                  const SizedBox(width: 8),
                  // Ödeme Türü
                  _buildPaymentTypeFilter(),
                  const SizedBox(width: 8),
                  // Filtreleri Temizle
                  if (_selectedStatus != null ||
                      _selectedWorkId != null ||
                      _selectedCourierId != null ||
                      _selectedPaymentType != null)
                    InkWell(
                      onTap: () {
                        setState(() {
                          // Tarihleri bugüne sıfırla
                          final now = DateTime.now();
                          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
                          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                          _selectedStatus = null;
                          _selectedWorkId = null;
                          _selectedCourierId = null;
                          _selectedPaymentType = null;
                        });
                        _loadOrders();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.clear, size: 16, color: Colors.red[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Temizle',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Sipariş Listesi
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Sipariş bulunamadı',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            return _buildOrderCard(order);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildStatusFilter() {
    return PopupMenuButton<int?>(
      child: _buildFilterChip(
        label: 'Durum',
        value: _selectedStatus == null
            ? 'Tümü'
            : _selectedStatus == 2
                ? 'Teslim Edildi'
                : 'İptal Edildi',
      ),
      onSelected: (value) {
        setState(() {
          _selectedStatus = value;
        });
        _loadOrders();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Tümü')),
        const PopupMenuItem(value: 2, child: Text('Teslim Edildi')),
        const PopupMenuItem(value: 3, child: Text('İptal Edildi')),
      ],
    );
  }

  Widget _buildWorkFilter() {
    // Seçili işletme adını bul
    String workName = 'Tümü';
    if (_selectedWorkId != null) {
      try {
        final work = _works.firstWhere(
          (w) {
            final workId = w['id'];
            // Tip kontrolü yap
            if (workId is int && _selectedWorkId is int) {
              return workId == _selectedWorkId;
            } else if (workId is String && _selectedWorkId is String) {
              return workId == _selectedWorkId;
            } else {
              return workId.toString() == _selectedWorkId.toString();
            }
          },
          orElse: () => <String, dynamic>{},
        );
        if (work.isNotEmpty) {
          workName = work['name']?.toString() ?? 'Bilinmiyor';
        }
      } catch (e) {
        debugPrint('İşletme bulunamadı: $e');
        workName = 'Bilinmiyor';
      }
    }
    
    return PopupMenuButton<int?>(
      child: _buildFilterChip(
        label: 'İşletme',
        value: workName,
      ),
      onSelected: (value) {
        setState(() {
          _selectedWorkId = value;
        });
        _loadOrders();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Tümü')),
        ..._works.map((work) => PopupMenuItem(
              value: work['id'],
              child: Text(work['name']),
            )),
      ],
    );
  }

  Widget _buildCourierFilter() {
    return PopupMenuButton<int?>(
      child: _buildFilterChip(
        label: 'Kurye',
        value: _selectedCourierId == null
            ? 'Tümü'
            : _couriers.firstWhere((c) => c['id'] == _selectedCourierId,
                    orElse: () => {'name': 'Bilinmiyor'})['name'],
      ),
      onSelected: (value) {
        setState(() {
          _selectedCourierId = value;
        });
        _loadOrders();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Tümü')),
        ..._couriers.map((courier) => PopupMenuItem(
              value: courier['id'],
              child: Text(courier['name']),
            )),
      ],
    );
  }

  Widget _buildPaymentTypeFilter() {
    return PopupMenuButton<int?>(
      child: _buildFilterChip(
        label: 'Ödeme Türü',
        value: _selectedPaymentType == null
            ? 'Tümü'
            : _selectedPaymentType == 1
                ? 'Nakit'
                : _selectedPaymentType == 2
                    ? 'Kredi Kartı'
                    : 'Diğer',
      ),
      onSelected: (value) {
        setState(() {
          _selectedPaymentType = value;
        });
        _loadOrders();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Tümü')),
        const PopupMenuItem(value: 1, child: Text('Nakit')),
        const PopupMenuItem(value: 2, child: Text('Kredi Kartı')),
      ],
    );
  }

  Widget _buildOrderCard(order_model.Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(orderId: order.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Sipariş ID
                  Expanded(
                    child: Text(
                      'Sipariş #${order.sId}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Durum badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(order.statusColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(order.statusColor).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      order.statusName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(order.statusColor),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // İşletme
              Row(
                children: [
                  Icon(Icons.restaurant, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.restaurantName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Müşteri
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.customer.fullname,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Tarih ve Tutar
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(order.sCdate),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${order.payment.amount.toStringAsFixed(2)} TL',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              if (order.courierName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.local_shipping, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      order.courierName!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
