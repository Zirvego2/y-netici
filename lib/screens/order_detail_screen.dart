import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zirvego_main_app/services/order_service.dart';
import 'package:zirvego_main_app/services/courier_service.dart';
import 'package:zirvego_main_app/services/auth_service.dart';
import 'package:zirvego_main_app/models/order.dart' as order_model;
import 'package:zirvego_main_app/models/courier_info.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  final CourierService _courierService = CourierService();
  
  order_model.Order? _order;
  List<CourierInfo> _couriers = [];
  Map<int, int> _courierOrderCounts = {}; // Kurye ID -> Sipariş sayısı
  bool _isLoading = true;
  String? _error;
  int? _selectedCourierId;
  GoogleMapController? _mapController;
  LatLng? _orderLocation;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminData = authService.adminData;
      final bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;

      // Sipariş bilgilerini çek
      final order = await _orderService.getOrderById(widget.orderId);
      
      // Kurye listesini çek
      final allCouriers = await _courierService.getCouriersByBay(bayId);
      
      // Sadece aktif kuryeleri filtrele (status 0 hariç: Boşta olanlar gösterilmez)
      // Status 1: Meşgul, 2: Molada, 3+: Kaza vb. gösterilir
      final couriers = allCouriers.where((courier) => 
        courier.status != null && courier.status != 0
      ).toList();

      if (order == null) {
        setState(() {
          _error = 'Sipariş bulunamadı';
          _isLoading = false;
        });
        return;
      }

      // Her kurye için aktif sipariş sayısını çek
      final Map<int, int> orderCounts = {};
      final firestore = FirebaseFirestore.instance;
      for (final courier in couriers) {
        try {
          final ordersQuery = await firestore
              .collection('t_orders')
              .where('s_courier', isEqualTo: courier.sId)
              .where('s_stat', whereIn: [0, 1, 4])
              .where('s_bay', isEqualTo: bayId)
              .get();
          orderCounts[courier.sId] = ordersQuery.docs.length;
        } catch (e) {
          print('Kurye sipariş sayısı hatası: $e');
          orderCounts[courier.sId] = 0;
        }
      }

      // Lokasyon bilgisini al
      LatLng? location;
      if (order.customer.location != null) {
        location = LatLng(
          order.customer.location!['latitude']!,
          order.customer.location!['longitude']!,
        );
      }

      setState(() {
        _order = order;
        _couriers = couriers;
        _courierOrderCounts = orderCounts;
        _selectedCourierId = order.sCourier;
        _orderLocation = location;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Hata: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _assignCourier(int? courierId) async {
    if (_order == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = courierId != null && courierId > 0
          ? await _orderService.assignCourier(_order!.id, courierId)
          : await _orderService.unassignCourier(_order!.id);

      if (success) {
        // Sipariş bilgilerini yeniden yükle
        await _loadOrderDetails();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                courierId != null && courierId > 0
                    ? 'Kurye atandı'
                    : 'Kurye ataması kaldırıldı',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kurye ataması yapılamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleManualDeliver() async {
    if (_order == null) return;

    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Manual Teslim',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Sipariş #${_order!.sId} teslim edildi olarak işaretlenecek. Emin misiniz?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: GoogleFonts.inter(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Teslim Et',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _orderService.manualDeliver(_order!.id);

      if (success) {
        // Sipariş bilgilerini yeniden yükle
        await _loadOrderDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş teslim edildi olarak işaretlendi'),
              backgroundColor: Colors.green,
            ),
          );
          // Geri dön
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teslim işlemi başarısız'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancelOrder() async {
    if (_order == null) return;

    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Paket İptal',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Sipariş #${_order!.sId} iptal edilecek. Bu işlem geri alınamaz. Emin misiniz?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: GoogleFonts.inter(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'İptal Et',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _orderService.cancelOrder(_order!.id);

      if (success) {
        // Sipariş bilgilerini yeniden yükle
        await _loadOrderDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş iptal edildi'),
              backgroundColor: Colors.orange,
            ),
          );
          // Geri dön
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İptal işlemi başarısız'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCourierSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Kurye Seç',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Kurye listesi
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _couriers.length + 1, // +1 for "Atama Kaldır" option
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Atama kaldır seçeneği
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _assignCourier(null);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cancel, color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Atama Kaldır',
                                style: GoogleFonts.inter(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final courier = _couriers[index - 1];
                    final isSelected = _selectedCourierId == courier.sId;
                    final orderCount = _courierOrderCounts[courier.sId] ?? 0;
                    
                    // Status rengi - Sipariş sayısına göre dinamik hesapla
                    Color statusColor;
                    String statusText;
                    
                    // Molada (3) veya Kaza (4) durumları değişmez
                    if (courier.status == 3 || courier.status == 4) {
                      if (courier.status == 3) {
                        statusColor = Colors.orange;
                        statusText = 'Molada';
                      } else {
                        statusColor = Colors.grey[800]!;
                        statusText = 'Kaza';
                      }
                    } else {
                      // Sipariş sayısına göre status belirle
                      if (orderCount > 0) {
                        statusColor = Colors.blue;
                        statusText = 'Meşgul';
                      } else {
                        // Sipariş yoksa Müsait göster
                        statusColor = Colors.green;
                        statusText = 'Müsait';
                      }
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _assignCourier(courier.sId);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E3A8A).withOpacity(0.1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          courier.fullName,
                                          style: GoogleFonts.inter(
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            fontSize: 14,
                                            color: isSelected
                                                ? const Color(0xFF1E3A8A)
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: statusColor.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (courier.phone != null) ...[
                                        Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          courier.phone!,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Icon(Icons.shopping_bag, size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$orderCount sipariş',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: orderCount > 0
                                              ? Colors.orange[700]
                                              : Colors.grey[600],
                                          fontWeight: orderCount > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Sipariş Detayı',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Sipariş Detayı',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Sipariş bulunamadı',
                style: GoogleFonts.inter(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sipariş #${order.sId}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Harita
            if (_orderLocation != null)
              Container(
                height: 250,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                clipBehavior: Clip.antiAlias,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _orderLocation!,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('order_location'),
                      position: _orderLocation!,
                      infoWindow: InfoWindow(
                        title: 'Sipariş Lokasyonu',
                        snippet: order.customer.address,
                      ),
                    ),
                  },
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  mapType: MapType.normal,
                  compassEnabled: false,
                  liteModeEnabled: false,
                  minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                    Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                    Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                  },
                ),
              ),

            // Sipariş Bilgileri
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sipariş Bilgileri',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Durum
                  _buildInfoRow(
                    'Durum',
                    order.statusName,
                    icon: Icons.info_outline,
                    valueColor: Color(order.statusColor),
                  ),
                  
                  // Platform
                  _buildInfoRow(
                    'Platform',
                    order.platformName,
                    icon: Icons.shopping_bag,
                  ),
                  
                  // Tarih
                  _buildInfoRow(
                    'Oluşturulma',
                    '${order.formattedCreateTime} - ${_formatDate(order.sCdate)}',
                    icon: Icons.access_time,
                  ),
                  
                  // Ödeme
                  _buildInfoRow(
                    'Ödeme',
                    '${order.payment.typeName} - ${order.payment.amount.toStringAsFixed(2)} TL',
                    icon: Icons.payment,
                  ),
                  
                  const Divider(height: 32),
                  
                  // Restoran Bilgileri
                  Text(
                    'Restoran',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow(
                    'İşletme Adı',
                    order.restaurantName,
                    icon: Icons.restaurant,
                  ),
                  
                  if (order.restaurantPhone != null)
                    _buildInfoRow(
                      'Telefon',
                      order.restaurantPhone!,
                      icon: Icons.phone,
                    ),
                  
                  const Divider(height: 32),
                  
                  // Müşteri Bilgileri
                  Text(
                    'Müşteri',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow(
                    'Ad Soyad',
                    order.customer.fullname,
                    icon: Icons.person,
                  ),
                  
                  _buildInfoRow(
                    'Telefon',
                    order.customer.phone,
                    icon: Icons.phone,
                  ),
                  
                  _buildInfoRow(
                    'Adres',
                    order.customer.address,
                    icon: Icons.location_on,
                    maxLines: 3,
                  ),
                  
                  if (order.customer.note != null && order.customer.note!.isNotEmpty)
                    _buildInfoRow(
                      'Not',
                      order.customer.note!,
                      icon: Icons.note,
                      maxLines: 3,
                    ),
                  
                  const Divider(height: 32),
                  
                  // Kurye Atama
                  Text(
                    'Kurye',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Teslim edildiyse teslim eden kurye, değilse atanan kurye
                  if (order.sStat == 2 && order.courierName != null)
                    _buildInfoRow(
                      'Teslim Eden Kurye',
                      order.courierName!,
                      icon: Icons.check_circle,
                      valueColor: Colors.green[700]!,
                    )
                  else if (order.courierName != null)
                    _buildInfoRow(
                      'Atanan Kurye',
                      order.courierName!,
                      icon: Icons.local_shipping,
                      valueColor: const Color(0xFF1E3A8A),
                    ),
                  
                  if (order.sCourier == 0 && order.sStat != 2)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Atama Bekliyor',
                            style: GoogleFonts.inter(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Manual Teslim ve Paket İptal butonları
                  Row(
                    children: [
                      // Manual Teslim butonu
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading || order.sStat == 2 || order.sStat == 3
                              ? null
                              : () => _handleManualDeliver(),
                          icon: const Icon(Icons.check_circle),
                          label: Text(
                            'Manual Teslim',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Paket İptal butonu
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading || order.sStat == 2 || order.sStat == 3
                              ? null
                              : () => _handleCancelOrder(),
                          icon: const Icon(Icons.cancel),
                          label: Text(
                            'Paket İptal',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.black87,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
