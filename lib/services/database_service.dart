import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'database_helper.dart';

/// Bu servis, Yönetici ve ÇOKLU Personel hesaplarını yönetir.
class DatabaseService {
  final _secureStorage = const FlutterSecureStorage();
  static const _isRegisteredKey = 'isRegistered';
  static const _adminExistsKey = 'hasAdmin';
  static const _verificationCodeKey = 'verificationCode';
  static const _managedUsersKey =
      'managedUsers'; // Personel listesi burada tutulur

  Future<void> _setRegistered(bool isRegistered) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isRegisteredKey, isRegistered);
  }

  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isRegisteredKey) ?? false;
  }

  Future<bool> hasAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adminExistsKey) ?? false;
  }

  /// Yönetici (Ana Kullanıcı) verilerini kaydeder.
  Future<void> saveUserData({
    required String companyName,
    required String userName,
    required String userContact,
    required String userEmail,
    required String userPassword,
    required String quickLoginPin,
    required String userRole,
    String? userFaceImage,
    required String termsAcceptedOn,
    String? deviceId,
    String? status,
    String? licenseStatus,
    String? address,
    String? companyPhone,
    String? taxNumber,
  }) async {
    await _secureStorage.write(key: 'companyName', value: companyName);
    await _secureStorage.write(key: 'userName', value: userName);
    await _secureStorage.write(key: 'userContact', value: userContact);
    await _secureStorage.write(key: 'userEmail', value: userEmail);
    await _secureStorage.write(key: 'userPassword', value: userPassword);
    await _secureStorage.write(key: 'quickLoginPin', value: quickLoginPin);
    await _secureStorage.write(key: 'userRole', value: userRole);
    await _secureStorage.write(key: 'termsAcceptedOn', value: termsAcceptedOn);

    if (address != null) {
      await _secureStorage.write(key: 'address', value: address);
    }
    if (companyPhone != null) {
      await _secureStorage.write(key: 'companyPhone', value: companyPhone);
    }
    if (taxNumber != null) {
      await _secureStorage.write(key: 'taxNumber', value: taxNumber);
    }

    if (deviceId != null) {
      await _secureStorage.write(key: 'deviceId', value: deviceId);
    }
    if (status != null) {
      await _secureStorage.write(key: 'status', value: status);
    }
    if (licenseStatus != null) {
      await _secureStorage.write(key: 'licenseStatus', value: licenseStatus);
    }

    if (userFaceImage != null) {
      await _secureStorage.write(key: 'userFaceImage', value: userFaceImage);
    }

    // Sosyal medya varsayılanları
    await _secureStorage.write(key: 'social_instagram_enabled', value: '0');
    await _secureStorage.write(key: 'social_instagram_link', value: '');
    await _secureStorage.write(key: 'social_whatsapp_enabled', value: '0');
    await _secureStorage.write(key: 'social_whatsapp_link', value: '');
    await _secureStorage.write(key: 'social_website_enabled', value: '0');
    await _secureStorage.write(key: 'social_website_link', value: '');
    await _secureStorage.write(key: 'social_twitter_enabled', value: '0');
    await _secureStorage.write(key: 'social_twitter_link', value: '');
    await _secureStorage.write(key: 'social_facebook_enabled', value: '0');
    await _secureStorage.write(key: 'social_facebook_link', value: '');
    await _secureStorage.write(key: 'social_maps_enabled', value: '0');
    await _secureStorage.write(key: 'social_maps_link', value: '');

    if (userRole == 'Yönetici') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adminExistsKey, true);
    }
    await _setRegistered(true);
  }

  Future<String?> readValue(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<Map<String, String>> readAllUserData() async {
    return await _secureStorage.readAll();
  }

  /// Yönetici verilerini günceller (Sadece ana hesap)
  Future<void> updateUserData(Map<String, dynamic> updatedUser) async {
    for (var entry in updatedUser.entries) {
      if (entry.key.isNotEmpty && entry.value != null) {
        // Eğer güncellenen veri personel listesi değilse ana storage'a yaz
        if (entry.key != _managedUsersKey) {
          await _secureStorage.write(
            key: entry.key,
            value: entry.value.toString(),
          );
        }
      }
    }
  }

  Future<void> updatePassword(String newPassword, String newPin) async {
    await _secureStorage.write(key: 'userPassword', value: newPassword);
    await _secureStorage.write(key: 'quickLoginPin', value: newPin);
  }

  Future<void> setVerificationCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verificationCodeKey, code);
  }

  Future<String?> getVerificationCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_verificationCodeKey);
  }

  Future<void> clearAllData() async {
    // 1. Firebase oturumunu kapat
    await FirebaseService.instance.signOut();

    // 2. Güvenli depolamayı temizle (Şifreler, PIN'ler vb.)
    await _secureStorage.deleteAll();
    
    // 3. SharedPreferences'ı KÖKTEN temizle
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Tek bir anahtar değil, TÜM ayarları temizle
    
    // 4. SQLite veritabanını da fiziksel olarak temizle
    await DatabaseHelper.instance.clearDatabase();
    
    debugPrint("Tüm yerel veriler ve oturumlar temizlendi.");
  }

  Future<void> restoreAllData(Map<String, String> data) async {
    await clearAllData();
    for (var entry in data.entries) {
      await _secureStorage.write(key: entry.key, value: entry.value);
    }
    
    // Admin ve Register flaglerini kontrol et
    if (data.containsKey('userRole') && data['userRole'] == 'Yönetici') {
       final prefs = await SharedPreferences.getInstance();
       await prefs.setBool(_adminExistsKey, true);
    }
    // Veri yüklendiyse kayıtlı sayılır
    await _setRegistered(true);
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // LİSANS CACHE VE CİHAZ DENEME YÖNETİMİ
  // ---------------------------------------------------------------------------

  /// Cihazın daha önce 7 günlük deneme sürümünü kullanıp kullanmadığını kontrol eder.
  Future<bool> hasDeviceUsedTrial() async {
    final used = await _secureStorage.read(key: 'deviceTrialUsed');
    return used == 'true';
  }

  /// Cihazın 7 günlük deneme sürümünü kullandığını mühürler.
  Future<void> markDeviceTrialUsed(DateTime expiry) async {
    await _secureStorage.write(key: 'deviceTrialUsed', value: 'true');
    await _secureStorage.write(key: 'deviceTrialExpiry', value: expiry.toIso8601String());
    await saveLicenseCache(expiry, 'active', planName: 'Ücretsiz Deneme');
  }

  /// Lisans bilgilerini yerel hafızaya kaydeder.
  Future<void> saveLicenseCache(DateTime expiry, String status, {String? planName}) async {
    await _secureStorage.write(key: 'cachedExpiry', value: expiry.toIso8601String());
    await _secureStorage.write(key: 'cachedLicenseStatus', value: status);
    if (planName != null) {
      await _secureStorage.write(key: 'cachedPlanName', value: planName);
    }
    await _secureStorage.write(key: 'lastLicenseCheck', value: DateTime.now().toIso8601String());
  }

  /// Yerel hafızadaki lisans bilgilerini okur.
  Future<Map<String, String?>> readLicenseCache() async {
    return {
      'expiry': await _secureStorage.read(key: 'cachedExpiry'),
      'status': await _secureStorage.read(key: 'cachedLicenseStatus'),
      'planName': await _secureStorage.read(key: 'cachedPlanName'),
      'lastCheck': await _secureStorage.read(key: 'lastLicenseCheck'),
      'deviceTrialUsed': await _secureStorage.read(key: 'deviceTrialUsed'),
    };
  }

  /// Lisans süresi ve kalan zamanı matematiksel ve hassas olarak hesaplar.
  Future<Map<String, dynamic>> getLicenseRemainingInfo() async {
    final cache = await readLicenseCache();
    String planName = cache['planName'] ?? 'Ücretsiz Deneme';
    String status = cache['status'] ?? 'active';
    String? expiryStr = cache['expiry'];

    if (expiryStr == null || expiryStr.isEmpty) {
      return {
        'planName': planName,
        'status': status,
        'isExpired': false,
        'daysLeft': 7,
        'formatted': '7 gün deneme',
        'expiryDate': null,
      };
    }

    final DateTime? expiryDate = DateTime.tryParse(expiryStr);
    if (expiryDate == null) {
      return {
        'planName': planName,
        'status': status,
        'isExpired': false,
        'daysLeft': 0,
        'formatted': 'Belirsiz',
        'expiryDate': null,
      };
    }

    final now = DateTime.now();
    if (expiryDate.isBefore(now)) {
      return {
        'planName': planName,
        'status': 'expired',
        'isExpired': true,
        'daysLeft': 0,
        'hoursLeft': 0,
        'formatted': 'Süresi doldu',
        'expiryDate': expiryDate,
      };
    }

    final difference = expiryDate.difference(now);
    final int days = difference.inDays;
    final int hours = difference.inHours;

    String formattedText;
    if (days >= 1) {
      formattedText = '$days gün kaldı';
    } else if (hours >= 1) {
      formattedText = '$hours saat kaldı (Bugün bitiyor)';
    } else {
      formattedText = 'Son 1 saat içinde sona eriyor';
    }

    return {
      'planName': planName,
      'status': status,
      'isExpired': false,
      'daysLeft': days,
      'hoursLeft': hours,
      'formatted': formattedText,
      'expiryDate': expiryDate,
    };
  }

  // ---------------------------------------------------------------------------
  // ÇOKLU PERSONEL YÖNETİMİ (GÜNCELLENDİ)
  // ---------------------------------------------------------------------------

  /// Yardımcı metod: Mevcut personel listesini çeker
  Future<List<Map<String, dynamic>>> _getStaffList() async {
    final usersJson = await _secureStorage.read(key: _managedUsersKey);
    if (usersJson == null || usersJson.isEmpty) return [];
    try {
      final List<dynamic> decodedList = jsonDecode(usersJson);
      return decodedList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Yardımcı metod: Listeyi kaydeder
  Future<void> _saveStaffList(List<Map<String, dynamic>> list) async {
    await _secureStorage.write(key: _managedUsersKey, value: jsonEncode(list));
  }

  /// 1. Tüm Personelleri Listele
  Future<List<Map<String, dynamic>>> getAllStaff() async {
    return await _getStaffList();
  }

  /// 2. Yeni Personel Ekle (Otomatik ID atar)
  Future<void> addStaffUser(Map<String, dynamic> staffData) async {
    final list = await _getStaffList();

    // Basit bir ID üretme mantığı (Mevcut en büyük ID + 1)
    int newId = 1;
    if (list.isNotEmpty) {
      final ids = list.map((e) => e['id'] is int ? e['id'] as int : 0).toList();
      if (ids.isNotEmpty) {
        ids.sort();
        newId = ids.last + 1;
      }
    }

    final newStaff = Map<String, dynamic>.from(staffData);
    newStaff['id'] = newId; // ID'yi ekle

    list.add(newStaff);
    await _saveStaffList(list);

    // Cloud Sync
    final String? companyEmail = await readValue('userEmail');
    if (companyEmail != null) {
      await FirebaseService.instance.syncStaffMember(companyEmail, newStaff);
    }
  }

  /// 3. Personel Sil (ID'ye göre)
  Future<void> deleteUser(int id) async {
    final list = await _getStaffList();
    final staffToDelete = list.firstWhere((e) => e['id'] == id, orElse: () => {});
    
    list.removeWhere((element) => element['id'] == id);
    await _saveStaffList(list);

    // Cloud Sync
    if (staffToDelete.isNotEmpty) {
      final String? companyEmail = await readValue('userEmail');
      final String? staffEmail = staffToDelete['userEmail'];
      if (companyEmail != null && staffEmail != null) {
        await FirebaseService.instance.deleteStaffMemberFromCloud(companyEmail, staffEmail);
      }
    }
  }

  /// 4. Personel Güncelle (ID'ye göre)
  Future<void> updateStaffById(int id, Map<String, dynamic> data) async {
    final list = await _getStaffList();
    final index = list.indexWhere((element) => element['id'] == id);

    if (index != -1) {
      final existing = list[index];
      // Mevcut veri ile yeni veriyi birleştir, ID'yi koru
      final updated = {...existing, ...data};
      updated['id'] = id;
      list[index] = updated;
      await _saveStaffList(list);

      // Cloud Sync
      final String? companyEmail = await readValue('userEmail');
      if (companyEmail != null) {
        await FirebaseService.instance.syncStaffMember(companyEmail, updated);
      }
    }
  }

  // --- Eski metodlar (Geriye dönük uyumluluk için, gerekirse kaldırılabilir) ---
  Future<void> updateStaffUser(Map<String, dynamic> staffUser) async {
    // Eski versiyon tek bir kullanıcıyı overwrite ediyordu.
    // Yeni sistemde addStaffUser kullanılmalı.
    await addStaffUser(staffUser);
  }

  Future<Map<String, dynamic>?> getStaffUser() async {
    // Eski versiyon ilk kullanıcıyı dönüyordu.
    final list = await getAllStaff();
    if (list.isNotEmpty) return list.first;
    return null;
  }
  // ---------------------------------------------------------------------------

  /// Login ekranı için Yönetici + TÜM Personel listesini döndürür.
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    List<Map<String, dynamic>> allUsers = [];

    // 1. Yöneticiyi al (SecureStorage root verileri)
    final mainUserData = await readAllUserData();
    if (mainUserData.isNotEmpty && mainUserData.containsKey('userEmail')) {
      final adminUser = Map<String, dynamic>.from(mainUserData);
      // Yöneticiye sabit bir ID verelim (çakışma olmaması için 0)
      adminUser['id'] = 0;
      allUsers.add(adminUser);
    }

    // 2. Tüm Personelleri al (Managed list)
    final staffList = await getAllStaff();
    allUsers.addAll(staffList);

    return allUsers;
  }
}
