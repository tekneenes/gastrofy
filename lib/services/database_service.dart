import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) async {
    await _secureStorage.write(key: 'companyName', value: companyName);
    await _secureStorage.write(key: 'userName', value: userName);
    await _secureStorage.write(key: 'userContact', value: userContact);
    await _secureStorage.write(key: 'userEmail', value: userEmail);
    await _secureStorage.write(key: 'userPassword', value: userPassword);
    await _secureStorage.write(key: 'quickLoginPin', value: quickLoginPin);
    await _secureStorage.write(key: 'userRole', value: userRole);
    await _secureStorage.write(key: 'termsAcceptedOn', value: termsAcceptedOn);

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
  Future<void> updateUserData(Map<String, dynamic> updatedUser,
      {required userContact,
      required String companyName,
      required String userName,
      required String userEmail}) async {
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
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isRegisteredKey);
    await prefs.remove(_verificationCodeKey);
    await prefs.remove(_adminExistsKey);
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
  }

  /// 3. Personel Sil (ID'ye göre)
  Future<void> deleteUser(int id) async {
    final list = await _getStaffList();
    list.removeWhere((element) => element['id'] == id);
    await _saveStaffList(list);
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
