import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zirvego_main_app/services/auth_service.dart';
import 'package:zirvego_main_app/services/order_service.dart';
import 'package:zirvego_main_app/services/courier_service.dart';
import 'package:zirvego_main_app/services/notification_service.dart';
import 'package:zirvego_main_app/providers/order_provider.dart';
import 'package:zirvego_main_app/widgets/order_card.dart';
import 'package:zirvego_main_app/models/order.dart' as order_model;
import 'package:zirvego_main_app/models/courier_info.dart';
import 'package:zirvego_main_app/screens/order_detail_screen.dart';
import 'package:zirvego_main_app/screens/notifications_settings_screen.dart';
import 'package:zirvego_main_app/screens/orders_screen.dart';
import 'package:zirvego_main_app/screens/couriers_screen.dart';
import 'package:zirvego_main_app/screens/map_screen.dart';
import 'package:zirvego_main_app/screens/daily_average_screen.dart';
import 'package:zirvego_main_app/screens/courier_report_screen.dart';
import 'package:zirvego_main_app/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();
  final CourierService _courierService = CourierService();
  // Kurye atanan siparişlerin ID'lerini takip et (bildirim göstermek için)
  final Set<String> _assignedOrderIds = {};
  // Yeni siparişleri takip et (bildirim göstermek için)
  final Set<int> _seenOrderIds = {};
  // İlk yükleme tamamlandı mı? (toplu bildirim önleme)
  bool _isInitialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Bay ID'yi ayarla ve bildirim izni iste
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminData = authService.adminData;
      final bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;
      debugPrint('🔍 Bay ID: $bayId');
      debugPrint('🔍 Admin Data: $adminData');
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.setBayId(bayId);
      
      // Bay ID'yi SharedPreferences'a kaydet (background service için)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_bay_id', bayId);
      
      // Bildirime tıklanarak açılan sipariş ID'lerini yükle
      // Böylece bu siparişler için tekrar bildirim gösterilmeyecek
      final seenOrderIdsFromNotification = prefs.getStringList('seen_order_ids_from_notification') ?? [];
      for (final orderIdStr in seenOrderIdsFromNotification) {
        final orderId = int.tryParse(orderIdStr);
        if (orderId != null) {
          _seenOrderIds.add(orderId);
          debugPrint('✅ Bildirime tıklanan sipariş ID yüklendi: $orderId');
        }
      }
      
      // Bildirim izni iste (giriş yaptıktan sonra)
      debugPrint('📱 Bildirim izni kontrol ediliyor...');
      final permissionGranted = await NotificationService().requestPermissionIfNeeded();
      if (permissionGranted) {
        debugPrint('✅ Bildirim izni verildi');
      } else {
        debugPrint('⚠️ Bildirim izni verilmedi');
      }
    });
  }

  // Bildirim ayarlarını oku (SharedPreferences'tan)
  Future<bool> _getNotificationSetting(String key, {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  // Kompakt menü öğesi widget'ı
  Widget _buildCompactMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? Colors.grey[700],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final adminData = authService.adminData;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Operasyon',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Yeni Siparişler'),
            Tab(text: 'Atanmış / Yolda'),
          ],
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await authService.logout();
              // AuthWrapper otomatik olarak LoginScreen'e yönlendirecek
            },
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      drawer: Drawer(
        width: 280, // Drawer genişliğini küçült
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header - Daha kompakt
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E3A8A),
                    const Color(0xFF1E3A8A).withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 24,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ZirveGo Yönetici',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (adminData?['name'] != null || adminData?['surname'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${adminData?['name'] ?? ''} ${adminData?['surname'] ?? ''}'.trim(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Menü Öğeleri - Daha kompakt
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildCompactMenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Operasyon',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),
                  _buildCompactMenuItem(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Siparişler',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrdersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCompactMenuItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Kuryeler',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CouriersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCompactMenuItem(
                    icon: Icons.map_outlined,
                    title: 'Harita',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCompactMenuItem(
                    icon: Icons.analytics_outlined,
                    title: 'Günlük Ortalama',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyAverageScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCompactMenuItem(
                    icon: Icons.assessment_outlined,
                    title: 'Kurye Raporu',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CourierReportScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCompactMenuItem(
                    icon: Icons.restaurant_outlined,
                    title: 'Restoranlar',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // Alt Menü Öğeleri
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildCompactMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Bildirimler',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCompactMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Ayarlar',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // Çıkış Yap
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildCompactMenuItem(
                icon: Icons.logout_rounded,
                title: 'Çıkış Yap',
                iconColor: Colors.red[600],
                textColor: Colors.red[600],
                onTap: () async {
                  Navigator.pop(context);
                  await authService.logout();
                },
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Yeni Siparişler Tab
          _buildOrdersList(isNewOrders: true),
          // Yoldaki Siparişler Tab
          _buildOrdersList(isNewOrders: false),
        ],
      ),
    );
  }

  Widget _buildOrdersList({required bool isNewOrders}) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        final stream = isNewOrders
            ? orderProvider.getNewOrdersStream()
            : orderProvider.getInTransitOrdersStream();

        return StreamBuilder<List<order_model.Order>>(
          stream: stream,
          builder: (context, snapshot) {
            // Debug log
            debugPrint('📦 Stream State: ${snapshot.connectionState}');
            debugPrint('📦 Has Error: ${snapshot.hasError}');
            if (snapshot.hasError) {
              debugPrint('📦 Error: ${snapshot.error}');
            }
            if (snapshot.hasData) {
              debugPrint('📦 Orders Count: ${snapshot.data?.length ?? 0}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Hata: ${snapshot.error}',
                      style: GoogleFonts.inter(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Retry
                        setState(() {});
                      },
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              );
            }

            final orders = snapshot.data ?? [];
            
            // İlk yüklemede mevcut tüm siparişleri _seenOrderIds'e ekle (bildirime tıklanarak açılan siparişler için)
            // UYGULAMA İÇİNDEYKEN BİLDİRİM GÖSTERME - Sadece FCM push notification'lar gösterilecek (arka planda/kapalıyken)
            if (isNewOrders && orders.isNotEmpty && !_isInitialLoadComplete) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // İlk yükleme: Tüm mevcut siparişleri görüldü olarak işaretle
                for (final order in orders) {
                  _seenOrderIds.add(order.sId);
                  debugPrint('📦 İlk yükleme - Sipariş görüldü olarak işaretlendi: #${order.sId}');
                }
                _isInitialLoadComplete = true;
                debugPrint('📦 İlk yükleme tamamlandı, ${orders.length} sipariş görüldü olarak işaretlendi');
              });
            }
            
            // Kurye atanan siparişler için bildirim gösterme kaldırıldı
            // UYGULAMA İÇİNDEYKEN BİLDİRİM GÖSTERME - Sadece FCM push notification'lar gösterilecek (arka planda/kapalıyken)
            // _assignedOrderIds'i temizle (kullanılmıyor ama temiz tutmak için)
            if (!isNewOrders && orders.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                for (final order in orders) {
                  if (_assignedOrderIds.contains(order.id)) {
                    // Set'ten kaldır (bildirim gösterilmeyecek)
                    setState(() {
                      _assignedOrderIds.remove(order.id);
                    });
                  }
                }
              });
            }
            
            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isNewOrders ? Icons.shopping_cart_outlined : Icons.local_shipping_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isNewOrders
                          ? 'Yeni sipariş bulunmuyor'
                          : 'Yolda sipariş bulunmuyor',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Stream otomatik güncellenecek
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return OrderCard(
                    order: order,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDetailScreen(orderId: order.id),
                        ),
                      );
                    },
                    onAssignCourier: () {
                      _showCourierSelectionDialog(order);
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCourierSelectionDialog(order_model.Order order) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminData = authService.adminData;
      final bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;

      // Kurye listesini çek
      final allCouriers = await _courierService.getCouriersByBay(bayId);
      
      // Sadece aktif kuryeleri filtrele (status 0 hariç: Pasif/Çalışmayanlar)
      final couriers = allCouriers.where((courier) => 
        courier.status != null && courier.status != 0
      ).toList();

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

      final selectedCourierId = order.sCourier;

      if (!mounted) return;
      
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
                    itemCount: couriers.length + 1, // +1 for "Atama Kaldır" option
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Atama kaldır seçeneği
                        return InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final success = await _orderService.unassignCourier(order.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Kurye ataması kaldırıldı' : 'Hata oluştu'),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                            }
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

                      final courier = couriers[index - 1];
                      final isSelected = selectedCourierId == courier.sId;
                      final orderCount = orderCounts[courier.sId] ?? 0;
                      
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
                        onTap: () async {
                          Navigator.pop(context);
                          final success = await _orderService.assignCourier(order.id, courier.sId);
                          if (mounted) {
                            if (success) {
                              // Kurye atama başarılı olduğunda, sipariş ID'sini kaydet
                              setState(() {
                                _assignedOrderIds.add(order.id);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${courier.fullName} atandı'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hata oluştu'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
