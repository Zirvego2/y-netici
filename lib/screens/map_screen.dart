import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zirvego_main_app/services/auth_service.dart';
import 'package:zirvego_main_app/models/order.dart' as order_model;
import 'package:zirvego_main_app/screens/order_detail_screen.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';

// GeoPoint'ten LatLng'e çeviren helper fonksiyon
LatLng? _parseLocation(dynamic location) {
  if (location == null) return null;

  double? lat, lng;

  // GeoPoint objesi (Firestore'dan direkt geliyor)
  if (location is GeoPoint) {
    lat = location.latitude;
    lng = location.longitude;
  }
  // Map formatı
  else if (location is Map) {
    if (location['latitude'] != null && location['longitude'] != null) {
      lat = (location['latitude'] as num).toDouble();
      lng = (location['longitude'] as num).toDouble();
    } else if (location['__lat__'] != null && location['__lon__'] != null) {
      lat = (location['__lat__'] as num).toDouble();
      lng = (location['__lon__'] as num).toDouble();
    } else if (location['lat'] != null && location['lng'] != null) {
      lat = (location['lat'] as num).toDouble();
      lng = (location['lng'] as num).toDouble();
    }
  }
  // String formatı: "[40.3400703° N, 27.95097° E km : 0.07]"
  else if (location is String) {
    final regex = RegExp(r'\[([\d.]+)°\s*N,\s*([\d.]+)°\s*E');
    final match = regex.firstMatch(location);
    if (match != null) {
      lat = double.tryParse(match.group(1)!);
      lng = double.tryParse(match.group(2)!);
    }
  }

  if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
    return LatLng(lat, lng);
  }

  return null;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  int? _bayId;
  
  // Stream subscription'ları
  StreamSubscription? _courierStreamSubscription;

  // Marker icon'ları (web'deki icon'lar)
  BitmapDescriptor? _businessIcon;
  BitmapDescriptor? _orderIcon;
  BitmapDescriptor? _courierStat1Icon; // Müsait
  BitmapDescriptor? _courierStat2Icon; // Meşgul
  BitmapDescriptor? _courierStat3Icon; // Molada
  BitmapDescriptor? _courierStat4Icon; // Kaza

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }
  
  void _startCourierLocationStream() {
    if (_bayId == null) return;
    
    final firestore = FirebaseFirestore.instance;
    
    // Kurye lokasyonlarını anlık takip et
    _courierStreamSubscription = firestore
        .collection('t_courier')
        .where('s_bay', isEqualTo: _bayId)
        .where('s_stat', whereIn: [1, 2, 3, 4]) // Tüm aktif kuryeler
        .snapshots()
        .listen((snapshot) {
      _updateCourierMarkers(snapshot.docs);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Icon'ları sadece bir kez yükle
    if (_businessIcon == null) {
      _loadMarkerIcons();
    }
  }

  // Asset'ten resim yükleyip resize eden helper fonksiyon
  Future<BitmapDescriptor> _resizeMarkerIcon(String assetPath, int targetWidth) async {
    // Asset'i byte array olarak yükle
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();
    
    // Byte array'i ui.Image'e çevir
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;
    
    // ui.Image'i byte array'e çevir
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List resizedBytes = byteData!.buffer.asUint8List();
    
    // BitmapDescriptor oluştur
    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  Future<void> _loadMarkerIcons() async {
    // Marker boyutunu optimize et
    // Web'deki marker boyutlarına göre ayarlanabilir
    final int targetSize = 60; // Marker boyutu
    
    _businessIcon = await _resizeMarkerIcon('assets/markers/home.png', targetSize);
    _orderIcon = await _resizeMarkerIcon('assets/markers/del_1.png', targetSize);
    _courierStat1Icon = await _resizeMarkerIcon('assets/markers/map_stat_1.png', targetSize);
    _courierStat2Icon = await _resizeMarkerIcon('assets/markers/map_stat_2.png', targetSize);
    _courierStat3Icon = await _resizeMarkerIcon('assets/markers/map_stat_3.png', targetSize);
    _courierStat4Icon = await _resizeMarkerIcon('assets/markers/map_stat_4.png', targetSize);
    
    // Icon'lar yüklendikten sonra marker'ları yükle
    if (mounted) {
      await _loadMarkers();
    }
  }

  Future<void> _initializeMap() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final adminData = authService.adminData;
    _bayId = adminData?['s_bay'] ?? adminData?['s_id'] ?? 1;
    
    // Bay'ın konumunu al ve haritayı o konuma göre ortala
    await _loadBayLocation();
  }

  Future<void> _loadBayLocation() async {
    if (_bayId == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      
      // t_bay koleksiyonundan bay verisini çek
      final bayQuery = await firestore
          .collection('t_bay')
          .where('s_id', isEqualTo: _bayId)
          .limit(1)
          .get();

      if (bayQuery.docs.isNotEmpty) {
        final bayData = bayQuery.docs[0].data();
        final location = bayData['s_loc']?['ss_location'];
        
        if (location != null) {
          final position = _parseLocation(location);
          
          if (position != null && _mapController != null) {
            // Haritayı bay konumuna göre ortala
            await _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(position, 15),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Bay konumu yükleme hatası: $e');
    }
  }

  Future<void> _loadMarkers() async {
    if (_bayId == null) {
      debugPrint('🗺️ Bay ID null, marker yüklenemiyor');
      return;
    }

    debugPrint('🗺️ Marker yükleme başlatılıyor, Bay ID: $_bayId');

    setState(() {
      _isLoading = true;
      _markers.clear();
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final Set<Marker> newMarkers = {};

      // İşletmeleri yükle (t_work)
      debugPrint('🗺️ İşletmeler sorgulanıyor...');
      final workQuery = await firestore
          .collection('t_work')
          .where('s_bay', isEqualTo: _bayId)
          .get();
      
      debugPrint('🗺️ Bulunan işletme sayısı: ${workQuery.docs.length}');

      for (var doc in workQuery.docs) {
        final data = doc.data();
        final location = data['s_loc']?['ss_location'];
        final position = _parseLocation(location);
        
        if (position != null && _businessIcon != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('business_${doc.id}'),
              position: position,
              icon: _businessIcon!,
              infoWindow: InfoWindow(
                title: data['s_name'] ?? 'İşletme',
                snippet: data['s_loc']?['ss_adres'] ?? 'Adres yok',
              ),
            ),
          );
        }
      }

      // Siparişleri yükle (t_orders) - sadece aktif siparişler (s_stat: 0, 1)
      debugPrint('🗺️ Siparişler sorgulanıyor...');
      final ordersQuery = await firestore
          .collection('t_orders')
          .where('s_bay', isEqualTo: _bayId)
          .where('s_stat', whereIn: [0, 1])
          .get();
      
      debugPrint('🗺️ Bulunan aktif sipariş sayısı: ${ordersQuery.docs.length}');

      for (var doc in ordersQuery.docs) {
        final data = doc.data();
        final customerLoc = data['s_customer']?['ss_loc'];
        final position = _parseLocation(customerLoc);
        
        if (position != null && _orderIcon != null) {
          final orderId = data['s_id']?.toString() ?? doc.id;
          final customerName = data['s_customer']?['ss_fullname'] ?? 'Müşteri';
          
          newMarkers.add(
            Marker(
              markerId: MarkerId('order_${doc.id}'),
              position: position,
              icon: _orderIcon!,
              infoWindow: InfoWindow(
                title: 'Sipariş #$orderId',
                snippet: customerName,
              ),
              onTap: () {
                // Sipariş detay sayfasına git
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailScreen(
                      orderId: orderId,
                    ),
                  ),
                );
              },
            ),
          );
        }
      }

      // Kuryeleri stream ile yüklemeye başla (anlık güncellemeler için)
      _startCourierLocationStream();

      debugPrint('🗺️ Toplam marker sayısı: ${newMarkers.length}');

      setState(() {
        _markers = newMarkers;
        _isLoading = false;
      });

      // Haritayı tüm marker'ları gösterecek şekilde ayarla
      if (_mapController != null && newMarkers.isNotEmpty) {
        await _fitMarkers(newMarkers);
      }
    } catch (e) {
      debugPrint('Harita marker yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fitMarkers(Set<Marker> markers) async {
    if (markers.isEmpty || _mapController == null) return;

    try {
      final bounds = _calculateBounds(markers);
      // Padding'i azaltarak daha yakın göster (50px yerine 100px)
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    } catch (e) {
      debugPrint('Harita bounds hatası: $e');
    }
  }

  LatLngBounds _calculateBounds(Set<Marker> markers) {
    double? minLat, maxLat, minLng, maxLng;

    for (var marker in markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      minLat = minLat == null ? lat : (minLat < lat ? minLat : lat);
      maxLat = maxLat == null ? lat : (maxLat > lat ? maxLat : lat);
      minLng = minLng == null ? lng : (minLng < lng ? minLng : lng);
      maxLng = maxLng == null ? lng : (maxLng > lng ? maxLng : lng);
    }

    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
  }

  String _getCourierStatusText(int status) {
    switch (status) {
      case 1:
        return 'Müsait';
      case 2:
        return 'Meşgul';
      case 3:
        return 'Molada';
      case 4:
        return 'Kaza';
      default:
        return 'Müsait';
    }
  }

  void _updateCourierMarkers(List<QueryDocumentSnapshot> courierDocs) {
    // Mevcut kurye marker'larını kaldır
    _markers.removeWhere((marker) => marker.markerId.value.startsWith('courier_'));
    
    // Yeni kurye marker'larını ekle
    for (var doc in courierDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['s_loc'];
      final position = _parseLocation(location);
      
      if (position != null) {
        final status = data['s_stat'] ?? 1;
        BitmapDescriptor? courierIcon;
        
        switch (status) {
          case 1:
            courierIcon = _courierStat1Icon;
            break;
          case 2:
            courierIcon = _courierStat2Icon;
            break;
          case 3:
            courierIcon = _courierStat3Icon;
            break;
          case 4:
            courierIcon = _courierStat4Icon;
            break;
          default:
            courierIcon = _courierStat1Icon;
        }
        
        if (courierIcon != null) {
          final name = data['s_info']?['ss_name'] ?? 'Kurye';
          final surname = data['s_info']?['ss_surname'] ?? '';
          final fullName = '$name $surname'.trim();
          
          _markers.add(
            Marker(
              markerId: MarkerId('courier_${doc.id}'),
              position: position,
              icon: courierIcon,
              infoWindow: InfoWindow(
                title: fullName,
                snippet: _getCourierStatusText(status),
              ),
            ),
          );
        }
      }
    }
    
    // UI'ı güncelle
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _courierStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Harita',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMarkers,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(40.3522, 27.9767), // Bandırma default konumu
              zoom: 15,
            ),
            markers: _markers,
            onMapCreated: (controller) async {
              _mapController = controller;
              
              // POI'leri (park, restoran vs.) gizle
              await _mapController!.setMapStyle('''
                [
                  {
                    "featureType": "poi",
                    "stylers": [{"visibility": "off"}]
                  },
                  {
                    "featureType": "poi.business",
                    "stylers": [{"visibility": "off"}]
                  },
                  {
                    "featureType": "poi.park",
                    "stylers": [{"visibility": "off"}]
                  },
                  {
                    "featureType": "transit",
                    "stylers": [{"visibility": "off"}]
                  }
                ]
              ''');
              
              // Bay konumunu yükle ve haritayı ortala
              if (_bayId != null) {
                await _loadBayLocation();
              }
              
              // Marker'lar varsa onları da göster
              if (_markers.isNotEmpty) {
                await _fitMarkers(_markers);
              }
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
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gösterge',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLegendItem('İşletme', Colors.yellow),
                      const SizedBox(width: 12),
                      _buildLegendItem('Sipariş', Colors.orange),
                      const SizedBox(width: 12),
                      _buildLegendItem('Kurye (Müsait)', Colors.green),
                      const SizedBox(width: 12),
                      _buildLegendItem('Kurye (Meşgul)', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
