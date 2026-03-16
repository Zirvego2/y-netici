import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'courier_report_detail_screen.dart';

class CourierReportScreen extends StatefulWidget {
  const CourierReportScreen({super.key});

  @override
  State<CourierReportScreen> createState() => _CourierReportScreenState();
}

class _CourierReportScreenState extends State<CourierReportScreen> {
  int? _bayId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Son 24 saati göster
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    
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
          await _loadReportData();
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
      debugPrint('❌ Kurye Raporu hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReportData() async {
    if (_bayId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // PERFORMANS İYİLEŞTİRMESİ: Tarih filtresini Firestore sorgusuna ekle
      final ordersQuery = await firestore
          .collection('t_orders')
          .where('s_bay', isEqualTo: _bayId)
          .where('s_stat', isEqualTo: 2) // Teslim edilmiş
          .where('s_cdate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('s_cdate', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
          .get();

      debugPrint('📊 Tarih aralığındaki sipariş: ${ordersQuery.docs.length}');

      // Kurye bazlı gruplandırma
      Map<int, Map<String, dynamic>> courierData = {};

      for (var doc in ordersQuery.docs) {
        final orderData = doc.data();
        
        final courierId = orderData['s_courier'] as int?;
        if (courierId == null || courierId == 0) continue;

        // Kurye verisini başlat
        if (!courierData.containsKey(courierId)) {
          courierData[courierId] = {
            'courierId': courierId,
            'courierName': 'Kurye #$courierId',
            'orderCount': 0,
            'cashAmount': 0.0,
            'cashCount': 0,
            'cardAmount': 0.0,
            'cardCount': 0,
            'onlineAmount': 0.0,
            'onlineCount': 0,
            'totalDistance': 0.0,
          };
        }

        courierData[courierId]!['orderCount'] = 
            (courierData[courierId]!['orderCount'] as int) + 1;

        // Ödeme türü
        final paymentType = orderData['s_pay']?['ss_paytype'] as int?;
        final paymentAmountRaw = orderData['s_pay']?['ss_paycount'];
        final paymentAmount = paymentAmountRaw is num 
            ? paymentAmountRaw.toDouble() 
            : (paymentAmountRaw is String ? double.tryParse(paymentAmountRaw) ?? 0.0 : 0.0);

        if (paymentType == 0) {
          // Nakit
          courierData[courierId]!['cashAmount'] = 
              (courierData[courierId]!['cashAmount'] as double) + paymentAmount;
          courierData[courierId]!['cashCount'] = 
              (courierData[courierId]!['cashCount'] as int) + 1;
        } else if (paymentType == 1) {
          // Kredi Kartı
          courierData[courierId]!['cardAmount'] = 
              (courierData[courierId]!['cardAmount'] as double) + paymentAmount;
          courierData[courierId]!['cardCount'] = 
              (courierData[courierId]!['cardCount'] as int) + 1;
        } else if (paymentType == 2) {
          // Online
          courierData[courierId]!['onlineAmount'] = 
              (courierData[courierId]!['onlineAmount'] as double) + paymentAmount;
          courierData[courierId]!['onlineCount'] = 
              (courierData[courierId]!['onlineCount'] as int) + 1;
        }

        // Mesafe
        final distanceRaw = orderData['s_dinstance'];
        final distance = distanceRaw is num 
            ? distanceRaw.toDouble() 
            : (distanceRaw is String ? double.tryParse(distanceRaw) ?? 0.0 : 0.0);
        courierData[courierId]!['totalDistance'] = 
            (courierData[courierId]!['totalDistance'] as double) + distance;
      }

      // Kuryelerin isimlerini çek
      if (courierData.isNotEmpty) {
        debugPrint('📋 ${courierData.length} kurye için bilgi çekiliyor...');
        
        for (var courierId in courierData.keys) {
          try {
            final courierDoc = await firestore
                .collection('t_courier')
                .doc(courierId.toString())
                .get();

            if (courierDoc.exists) {
              final data = courierDoc.data();
              if (data != null) {
                String firstName = '';
                String lastName = '';
                
                final sInfo = data['s_info'];
                // s_info'nun Map olup olmadığını kontrol et
                if (sInfo is Map<String, dynamic>) {
                  firstName = sInfo['ss_name']?.toString() ?? '';
                  lastName = sInfo['ss_surname']?.toString() ?? '';
                } else {
                  debugPrint('⚠️ Kurye $courierId: s_info Map değil (${sInfo.runtimeType})');
                }
                
                final fullName = '$firstName $lastName'.trim();
                courierData[courierId]!['courierName'] = 
                    fullName.isNotEmpty ? fullName : 'Kurye #$courierId';
                
                debugPrint('✅ Kurye $courierId: ${courierData[courierId]!['courierName']}');
              }
            } else {
              debugPrint('⚠️ Kurye $courierId belgesi bulunamadı');
            }
          } catch (e) {
            debugPrint('❌ Kurye $courierId bilgisi alınamadı: $e');
            // Kurye adı zaten default olarak ayarlı, devam et
          }
        }
      }
      
      debugPrint('📊 Filtrelenmiş sipariş sayısı: ${courierData.values.fold<int>(0, (sum, item) => sum + (item['orderCount'] as int))}');

      // Liste haline getir ve sırala
      final reportList = courierData.values.toList();
      reportList.sort((a, b) => 
          (a['courierName'] as String).toLowerCase()
              .compareTo((b['courierName'] as String).toLowerCase()));

      setState(() {
        _reportData = reportList;
      });

    } catch (e) {
      debugPrint('❌ Kurye raporu hatası: $e');
      setState(() {
        _reportData = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        if (_startDate.isAfter(_endDate)) {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
      _loadReportData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );

    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
      _loadReportData();
    }
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _selectStartDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Başlangıç',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_startDate),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _selectEndDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bitiş',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_endDate),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () async {
          try {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourierReportDetailScreen(
                  courierId: data['courierId'] as int,
                  courierName: data['courierName'] as String,
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),
            );
          } catch (e) {
            debugPrint('❌ Detay sayfası açılırken hata: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Detay sayfası açılamadı: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Kurye İkonu
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: Colors.blue[700],
                  size: 20),
              ),
              const SizedBox(width: 12),
              // Kurye Bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['courierName'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 10,
                      runSpacing: 3,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Text(
                              '${data['orderCount']} Sipariş',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.route_outlined, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Text(
                              '${(data['totalDistance'] as double).toStringAsFixed(1)} km',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sipariş Sayısı Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${data['orderCount']}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Kurye Raporu',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateFilter(),
          const SizedBox(height: 8),
          // Özet Bilgi
          if (_reportData.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_reportData.length}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Kurye',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        '${_reportData.fold<int>(0, (sum, item) => sum + (item['orderCount'] as int))}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Toplam Sipariş',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        '${_reportData.fold<double>(0, (sum, item) => sum + (item['totalDistance'] as double)).toStringAsFixed(1)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Toplam KM',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Kurye Listesi
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Kurye raporları yükleniyor...',
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
                : _reportData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Seçili tarih aralığında\nteslim edilmiş sipariş bulunamadı',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReportData,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _reportData.length,
                          itemBuilder: (context, index) {
                            return _buildCourierCard(_reportData[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
