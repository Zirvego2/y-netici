import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zirvego_main_app/services/auth_service.dart';
import 'package:zirvego_main_app/services/courier_service.dart';
import 'package:zirvego_main_app/models/courier_info.dart';

class CouriersScreen extends StatefulWidget {
  const CouriersScreen({super.key});

  @override
  State<CouriersScreen> createState() => _CouriersScreenState();
}

class _CouriersScreenState extends State<CouriersScreen> {
  final CourierService _courierService = CourierService();
  
  List<CourierInfo> _couriers = [];
  Map<int, int> _courierOrderCounts = {}; // Kurye ID -> Aktif sipariş sayısı
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCouriers();
  }

  Future<void> _updateCourierStatus(int courierId, int newStatus) async {
    try {
      final success = await _courierService.updateCourierStatus(courierId, newStatus);
      
      if (!mounted) return;
      
      if (success) {
        // Kurye listesini yeniden yükle
        await _loadCouriers();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kurye durumu güncellendi'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Durum güncellenirken hata oluştu'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Status güncelleme hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadCouriers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminData = authService.adminData;
      final bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;

      // Kuryeleri yükle
      final couriers = await _courierService.getCouriersByBay(bayId);

      // Her kurye için aktif sipariş sayısını çek
      final Map<int, int> orderCounts = {};
      final firestore = FirebaseFirestore.instance;
      
      for (final courier in couriers) {
        try {
          final ordersQuery = await firestore
              .collection('t_orders')
              .where('s_courier', isEqualTo: courier.sId)
              .where('s_stat', whereIn: [0, 1, 4]) // Hazır, Yolda, İşletmede
              .where('s_bay', isEqualTo: bayId)
              .get();
          orderCounts[courier.sId] = ordersQuery.docs.length;
        } catch (e) {
          debugPrint('Kurye sipariş sayısı hatası: $e');
          orderCounts[courier.sId] = 0;
        }
      }

      setState(() {
        _couriers = couriers;
        _courierOrderCounts = orderCounts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Kurye yükleme hatası: $e');
      setState(() {
        _error = 'Kuryeler yüklenirken bir hata oluştu';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(int? status) {
    if (status == null) {
      return Colors.grey; // Çalışmıyor
    }
    switch (status) {
      case 0:
        return Colors.grey; // Çalışmıyor
      case 1:
        return Colors.green; // Müsait
      case 2:
        return Colors.orange; // Meşgul
      case 3:
        return Colors.blue; // Molada
      case 4:
        return Colors.red; // Kaza
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(int? status) {
    if (status == null) {
      return Icons.block; // Çalışmıyor
    }
    switch (status) {
      case 0:
        return Icons.block; // Çalışmıyor
      case 1:
        return Icons.check_circle; // Müsait
      case 2:
        return Icons.local_shipping; // Meşgul
      case 3:
        return Icons.coffee; // Molada
      case 4:
        return Icons.warning; // Kaza
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kuryeler',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCouriers,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCouriers,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _couriers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Kurye bulunamadı',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCouriers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _couriers.length,
                        itemBuilder: (context, index) {
                          final courier = _couriers[index];
                          final orderCount = _courierOrderCounts[courier.sId] ?? 0;
                          return _buildCourierCard(courier, orderCount);
                        },
                      ),
                    ),
    );
  }

  Widget _buildCourierCard(CourierInfo courier, int orderCount) {
    final statusColor = _getStatusColor(courier.status);
    final statusIcon = _getStatusIcon(courier.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Kurye bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    courier.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (courier.phone != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          courier.phone!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Aktif sipariş sayısı
                  Row(
                    children: [
                      Icon(Icons.shopping_bag, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Aktif: $orderCount',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Durum badge (tıklanabilir)
            PopupMenuButton<int>(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      courier.statusName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 14, color: statusColor),
                  ],
                ),
              ),
              onSelected: (newStatus) async {
                await _updateCourierStatus(courier.sId, newStatus);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      if (courier.status == 0 || courier.status == null)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                      if (courier.status != 0 && courier.status != null) const SizedBox(width: 18),
                      const Text('Çalışmıyor'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      if (courier.status == 1)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                      if (courier.status != 1) const SizedBox(width: 18),
                      const Text('Müsait'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      if (courier.status == 2)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                      if (courier.status != 2) const SizedBox(width: 18),
                      const Text('Meşgul'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    children: [
                      if (courier.status == 3)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                      if (courier.status != 3) const SizedBox(width: 18),
                      const Text('Molada'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 4,
                  child: Row(
                    children: [
                      if (courier.status == 4)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                      if (courier.status != 4) const SizedBox(width: 18),
                      const Text('Kaza'),
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
}
