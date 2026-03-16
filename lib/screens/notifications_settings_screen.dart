import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  // Bildirim ayarları (varsayılan: açık)
  bool _notificationsEnabled = true;
  bool _newOrderNotificationsEnabled = true;
  bool _permissionGranted = false;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _checkPermission();
  }

  // İzin durumunu kontrol et
  Future<void> _checkPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.areNotificationsEnabled();
        setState(() {
          _permissionGranted = granted ?? false;
        });
      }
    } else if (Platform.isIOS) {
      // iOS için izin kontrolü
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        setState(() {
          _permissionGranted = granted ?? false;
        });
      }
    }
  }

  // İzin iste
  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        final isGranted = granted ?? false;
        setState(() {
          _permissionGranted = isGranted;
        });
        if (isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim izni verildi'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim izni verilmedi. Lütfen ayarlardan izin verin.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  // Bildirim ayarlarını yükle
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _newOrderNotificationsEnabled = prefs.getBool('new_order_notifications_enabled') ?? true;
    });
  }

  // Kurye atama bildirim ayarını kaydet
  Future<void> _saveNotificationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  // Yeni sipariş bildirim ayarını kaydet
  Future<void> _saveNewOrderNotificationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('new_order_notifications_enabled', value);
    setState(() {
      _newOrderNotificationsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bildirim Ayarları',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // İzin Durumu
          if (!_permissionGranted)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Bildirim İzni Gerekli',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bildirimleri almak için cihazınızın bildirim iznini vermeniz gerekiyor.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestPermission,
                      icon: const Icon(Icons.notifications_active),
                      label: Text(
                        'İzin Ver',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Kurye Atama Bildirimleri
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(
              'Kurye Atama Bildirimleri',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              _notificationsEnabled ? 'Açık' : 'Kapalı',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                _saveNotificationSetting(value);
              },
              activeColor: const Color(0xFF1E3A8A),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Kurye atandığında uygulama içi bildirim gösterilir',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Divider(),
          
          // Yeni Sipariş Bildirimleri
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: Text(
              'Yeni Sipariş Bildirimleri',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              _newOrderNotificationsEnabled ? 'Açık' : 'Kapalı',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: Switch(
              value: _newOrderNotificationsEnabled,
              onChanged: (value) {
                _saveNewOrderNotificationSetting(value);
              },
              activeColor: const Color(0xFF1E3A8A),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Yeni sipariş geldiğinde sistem bildirimi gösterilir (arka planda çalışır)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
