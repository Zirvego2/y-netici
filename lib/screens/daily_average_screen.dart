import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:zirvego_main_app/services/auth_service.dart';

class DailyAverageScreen extends StatefulWidget {
  const DailyAverageScreen({super.key});

  @override
  State<DailyAverageScreen> createState() => _DailyAverageScreenState();
}

class _DailyAverageScreenState extends State<DailyAverageScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  int? _bayId;
  
  // İstatistikler
  int _totalOrders = 0;
  int _deliveredOrders = 0;
  int _canceledOrders = 0;
  int _activeOrders = 0;
  double _averageDeliveryTime = 0.0; // Dakika cinsinden
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final adminData = authService.adminData;
    _bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;
    
    await _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (_bayId == null) {
      debugPrint('📊 İstatistik: Bay ID null, yükleme yapılamıyor');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Seçilen tarihin 00:00 - 23:59 arası (tam gün)
      final startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      final endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

      debugPrint('📊 İstatistik: Bay ID: $_bayId');
      debugPrint('📊 İstatistik: Başlangıç: $startDate');
      debugPrint('📊 İstatistik: Bitiş: $endDate');

      // Siparişleri çek (s_cdate kullanıyoruz, s_create değil)
      final ordersQuery = await firestore
          .collection('t_orders')
          .where('s_bay', isEqualTo: _bayId)
          .where('s_cdate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('s_cdate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      debugPrint('📊 İstatistik: Bulunan sipariş sayısı: ${ordersQuery.docs.length}');

      int totalOrders = ordersQuery.docs.length;
      int deliveredOrders = 0;
      int canceledOrders = 0;
      int activeOrders = 0;
      double totalRevenue = 0.0;
      double totalDeliveryTimeMinutes = 0.0;
      int deliveryTimeCount = 0;

      for (var doc in ordersQuery.docs) {
        final data = doc.data();
        final status = data['s_stat'] ?? 0;
        
        // Duruma göre sayaçları artır
        if (status == 2) {
          deliveredOrders++;
          
          // Teslimat süresini hesapla
          final createTime = (data['s_cdate'] as Timestamp?)?.toDate();
          final deliveryTime = (data['s_ddate'] as Timestamp?)?.toDate();
          
          if (createTime != null && deliveryTime != null) {
            final duration = deliveryTime.difference(createTime);
            totalDeliveryTimeMinutes += duration.inMinutes.toDouble();
            deliveryTimeCount++;
          }
          
          // Geliri ekle
          final payment = data['s_pay'];
          if (payment != null) {
            final total = (payment['ss_paycount'] ?? 0);
            totalRevenue += (total is int ? total.toDouble() : (total as double));
          }
        } else if (status == 3) {
          canceledOrders++;
        } else if (status == 0 || status == 1) {
          activeOrders++;
        }
      }

      // Ortalama teslimat süresini hesapla
      double averageDeliveryTime = 0.0;
      if (deliveryTimeCount > 0) {
        averageDeliveryTime = totalDeliveryTimeMinutes / deliveryTimeCount;
      }

      debugPrint('📊 İstatistik: Toplam: $totalOrders, Teslim: $deliveredOrders, İptal: $canceledOrders, Aktif: $activeOrders');
      debugPrint('📊 İstatistik: Ortalama teslimat: ${averageDeliveryTime.toStringAsFixed(1)} dk, Gelir: ₺${totalRevenue.toStringAsFixed(2)}');

      setState(() {
        _totalOrders = totalOrders;
        _deliveredOrders = deliveredOrders;
        _canceledOrders = canceledOrders;
        _activeOrders = activeOrders;
        _averageDeliveryTime = averageDeliveryTime;
        _totalRevenue = totalRevenue;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('📊 İstatistik yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İstatistikler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadStatistics();
    }
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} dk';
    } else {
      final hours = minutes ~/ 60;
      final mins = (minutes % 60).toInt();
      return '${hours}s ${mins}dk';
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'tr_TR');
    final timeRangeFormat = DateFormat('HH:mm', 'tr_TR');
    final startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Günlük Ortalama',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarih seçici
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarih Aralığı',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateFormat.format(_selectedDate),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${timeRangeFormat.format(startDate)} - ${timeRangeFormat.format(endDate)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // İstatistikler
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadStatistics,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Ana istatistikler
                          _buildStatCard(
                            title: 'Ortalama Teslimat Süresi',
                            value: _formatDuration(_averageDeliveryTime),
                            icon: Icons.timer_outlined,
                            color: Colors.purple,
                            subtitle: 'Sipariş alımından teslime',
                          ),
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Toplam Sipariş',
                                  value: _totalOrders.toString(),
                                  icon: Icons.shopping_bag_outlined,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Teslim Edilen',
                                  value: _deliveredOrders.toString(),
                                  icon: Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Aktif Sipariş',
                                  value: _activeOrders.toString(),
                                  icon: Icons.local_shipping_outlined,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'İptal Edilen',
                                  value: _canceledOrders.toString(),
                                  icon: Icons.cancel_outlined,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Ek istatistikler
                          if (_deliveredOrders > 0) ...[
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.analytics_outlined, color: Colors.indigo[700], size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Performans Detayları',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    _buildDetailRow(
                                      'Başarı Oranı',
                                      '${(_deliveredOrders / _totalOrders * 100).toStringAsFixed(1)}%',
                                      Colors.green,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      'İptal Oranı',
                                      '${(_canceledOrders / _totalOrders * 100).toStringAsFixed(1)}%',
                                      Colors.red,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      'Ortalama Sipariş Tutarı',
                                      '₺${(_totalRevenue / _deliveredOrders).toStringAsFixed(2)}',
                                      Colors.teal,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
