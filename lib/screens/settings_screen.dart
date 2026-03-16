import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'notifications_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _adminData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getInt('adminId');

      if (adminId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('t_bay')
            .doc(adminId.toString())
            .get();

        if (doc.exists) {
          setState(() {
            _adminData = {
              'name': doc.data()?['s_info']?['ss_name'] ?? '',
              'surname': doc.data()?['s_info']?['ss_surname'] ?? '',
              'username': doc.data()?['s_info']?['ss_username'] ?? doc.data()?['s_username'] ?? '',
              'bayName': doc.data()?['s_bay_name'] ?? '',
              'phone': doc.data()?['s_phone'] ?? '',
              'address': doc.data()?['s_adres'] ?? '',
              's_id': doc.data()?['s_id'],
            };
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Admin bilgileri yüklenirken hata: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Şifre Değiştir',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mevcut Şifre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Yeni Şifre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Yeni Şifre (Tekrar)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yeni şifreler eşleşmiyor!')),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şifre en az 6 karakter olmalıdır!')),
                );
                return;
              }

              // Şifre değiştirme işlemi
              try {
                final adminId = _adminData?['s_id'];
                if (adminId != null) {
                  await FirebaseFirestore.instance
                      .collection('t_bay')
                      .doc(adminId.toString())
                      .update({
                    's_password': newPasswordController.text,
                    's_info.ss_password': newPasswordController.text,
                    's_password_updated': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Şifre başarıyla değiştirildi!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 24,
          color: iconColor ?? Colors.blue,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    if (_adminData == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Text(
              (_adminData?['name']?.substring(0, 1) ?? 'A').toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_adminData?['name'] ?? ''} ${_adminData?['surname'] ?? ''}'.trim(),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _adminData?['bayName'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${_adminData?['username'] ?? ''}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil Kartı
                  _buildProfileCard(),

                  // Hesap Ayarları
                  _buildSectionHeader('HESAP'),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          icon: Icons.person_outline,
                          title: 'Profil Bilgileri',
                          subtitle: _adminData?['username'] ?? '',
                          onTap: () {
                            // Profil düzenleme sayfası eklenebilir
                          },
                        ),
                        const Divider(height: 1),
                        _buildSettingsTile(
                          icon: Icons.lock_outline,
                          title: 'Şifre Değiştir',
                          subtitle: 'Hesap güvenliğinizi koruyun',
                          onTap: _showChangePasswordDialog,
                        ),
                        const Divider(height: 1),
                        _buildSettingsTile(
                          icon: Icons.phone_outlined,
                          title: 'Telefon',
                          subtitle: _adminData?['phone'] ?? 'Belirtilmemiş',
                          trailing: null,
                        ),
                      ],
                    ),
                  ),

                  // Bildirim Ayarları
                  _buildSectionHeader('BİLDİRİMLER'),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Bildirim Ayarları',
                      subtitle: 'Push bildirimleri ve uyarılar',
                      iconColor: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  // Uygulama Ayarları
                  _buildSectionHeader('UYGULAMA'),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          icon: Icons.info_outline,
                          title: 'Uygulama Hakkında',
                          subtitle: 'ZirveGo Yönetici v1.0.0',
                          iconColor: Colors.teal,
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'ZirveGo Yönetici',
                              applicationVersion: '1.0.0',
                              applicationIcon: const Icon(
                                Icons.delivery_dining,
                                size: 48,
                                color: Colors.blue,
                              ),
                              children: [
                                const Text(
                                  'ZirveGo teslimat yönetim platformu için yönetici uygulaması.',
                                ),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _buildSettingsTile(
                          icon: Icons.help_outline,
                          title: 'Yardım & Destek',
                          subtitle: 'SSS ve iletişim',
                          iconColor: Colors.purple,
                          onTap: () {
                            // Yardım sayfası eklenebilir
                          },
                        ),
                      ],
                    ),
                  ),

                  // Çıkış Yap
                  _buildSectionHeader(''),
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red[200]!),
                    ),
                    child: _buildSettingsTile(
                      icon: Icons.logout_rounded,
                      title: 'Çıkış Yap',
                      subtitle: 'Hesabınızdan çıkış yapın',
                      iconColor: Colors.red,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              'Çıkış Yap',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('İptal'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Çıkış Yap'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && mounted) {
                          await authService.logout();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
