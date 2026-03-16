import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zirvego_main_app/services/fcm_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isAuthenticated = false;
  bool _isLoading = true;
  Map<String, dynamic>? _adminData;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get adminData => _adminData;

  AuthService() {
    _checkAuthStatus();
  }

  // Uygulama başlangıcında auth durumunu kontrol et
  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAdminLogin = prefs.getBool('isAdminLogin') ?? false;
      final adminDataString = prefs.getString('adminData');

      if (isAdminLogin && adminDataString != null) {
        try {
          _adminData = Map<String, dynamic>.from(
            json.decode(adminDataString),
          );
          _isAuthenticated = true;
        } catch (e) {
          debugPrint('Admin data parse error: $e');
          // Hatalı veri varsa temizle
          await prefs.remove('isAdminLogin');
          await prefs.remove('adminData');
        }
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login işlemi
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Login başlatılıyor...');
      debugPrint('🔐 Kullanıcı adı: $username');
      
      _isLoading = true;
      notifyListeners();

      // Firestore'da t_bay koleksiyonunda kullanıcıyı ara
      debugPrint('🔐 Firestore sorgusu başlatılıyor...');
      final querySnapshot = await _firestore
          .collection('t_bay')
          .where('s_username', isEqualTo: username)
          .where('s_password', isEqualTo: password)
          .limit(1)
          .get();

      debugPrint('🔐 Sorgu tamamlandı. Bulunan döküman sayısı: ${querySnapshot.docs.length}');

      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ Kullanıcı bulunamadı!');
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Kullanıcı adı veya şifre hatalı.',
        };
      }

      final userData = querySnapshot.docs[0].data();
      debugPrint('🔐 Kullanıcı bulundu: ${userData['s_username']}');
      debugPrint('✅ Giriş onaylandı');

      // Admin girişi başarılı
      _adminData = {
        'name': userData['s_info']?['ss_name'] ?? '',
        'surname': userData['s_info']?['ss_surname'] ?? '',
        'bayName': userData['s_bay_name'] ?? '',
        'username': userData['s_username'] ?? '',
        's_id': userData['s_id'],
        's_bay': userData['s_bay'],
      };

      debugPrint('✅ Admin data oluşturuldu: $_adminData');

      // SharedPreferences'a kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdminLogin', true);
      await prefs.setString('adminData', json.encode(_adminData));
      
      debugPrint('✅ SharedPreferences kaydedildi');

      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ Login başarılı!');

      // FCM token'ı kaydet (login sonrası - FCMService zaten otomatik kaydediyor)
      // Token alındığında otomatik olarak Firestore'a kaydedilir

      return {
        'success': true,
        'message': 'Giriş başarılı!',
        'data': _adminData,
      };
    } catch (e) {
      debugPrint('❌ Login hatası: $e');
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Bir hata oluştu. Lütfen tekrar deneyin.',
      };
    }
  }

  // Logout işlemi
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isAdminLogin');
      await prefs.remove('adminData');

      _isAuthenticated = false;
      _adminData = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }
}
