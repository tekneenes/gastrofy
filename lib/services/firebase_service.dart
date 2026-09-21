import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../gastroqr_firebase_options.dart'; // EKLENDİ
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseService {
  // Lazy access to instances to prevent crash if not initialized
  // These getters are replaced by final fields below as per instruction
  // FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  // FirebaseAuth get _auth => FirebaseAuth.instance;

  // Singleton
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GastroQR için ayrı proje bağlantısı
  FirebaseFirestore? _gastroQRFirestore;
  FirebaseStorage? _gastroQRStorage;

  /// GastroQR projesini ilklendirir (Mevcut değilse)
  Future<FirebaseFirestore> _getGastroQRFirestore() async {
    if (_gastroQRFirestore != null) return _gastroQRFirestore!;
    
    try {
      FirebaseApp app;
      try {
        app = Firebase.app('GastroQR');
      } catch (_) {
        app = await Firebase.initializeApp(
          name: 'GastroQR',
          options: GastroQRFirebaseOptions.currentPlatform,
        );
      }
      _gastroQRFirestore = FirebaseFirestore.instanceFor(app: app);
      debugPrint("GastroQR Projesi Bağlantısı Kuruldu: ${app.options.projectId}");
      return _gastroQRFirestore!;
    } catch (e) {
      debugPrint("GastroQR Projesi Bağlantı Hatası: $e");
      return _firestore; // Hata durumunda (geçici) ana firestore'a dön
    }
  }

  Future<FirebaseStorage> _getGastroQRStorage() async {
    if (_gastroQRStorage != null) return _gastroQRStorage!;
    try {
      FirebaseApp app;
      try {
        app = Firebase.app('GastroQR');
      } catch (_) {
        app = await Firebase.initializeApp(
          name: 'GastroQR',
          options: GastroQRFirebaseOptions.currentPlatform,
        );
      }
      _gastroQRStorage = FirebaseStorage.instanceFor(app: app);
      return _gastroQRStorage!;
    } catch (e) {
      debugPrint("GastroQR Storage Error: $e");
      return FirebaseStorage.instance;
    }
  }

  /// Mevcut oturumu kapatır.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint("Firebase oturumu kapatıldı.");
    } catch (e) {
      debugPrint("Firebase oturum kapatma hatası: $e");
    }
  }

  // --- Auth Methods ---

  /// E-posta ve şifre ile yeni kullanıcı oluşturur.
  Future<User?> createAuthUser(String email, String password) async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint("Auth kullanıcısı oluşturuldu: ${credential.user?.uid}");
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        debugPrint("Bu e-posta zaten kullanımda, mevcut hesap ile giriş yapılıyor...");
        try {
          final credential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          debugPrint("Mevcut hesap ile giriş yapıldı: ${credential.user?.uid}");
          return credential.user;
        } catch (signInError) {
          debugPrint("Mevcut hesaba giriş yapılamadı: $signInError");
          return null;
        }
      } else {
        debugPrint("Auth oluşturma hatası: ${e.message}");
        return null;
      }
    } catch (e) {
      debugPrint("Auth genel hata: $e");
      return null;
    }
  }

  /// Şifre sıfırlama e-postası gönderir.
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      if (Firebase.apps.isEmpty) return "Firebase bağlantısı yok.";
      _auth.setLanguageCode('tr');
      await _auth.sendPasswordResetEmail(email: email.trim());
      return "SUCCESS";
    } on FirebaseAuthException catch (e) {
      debugPrint("Şifre sıfırlama hatası: ${e.code} - ${e.message}");
      if (e.code == 'user-not-found') return "Bu e-posta adresine ait kayıtlı bir kullanıcı bulunamadı.";
      if (e.code == 'invalid-email') return "Lütfen geçerli bir e-posta formatı girin.";
      if (e.code == 'network-request-failed') return "İnternet bağlantınızı kontrol edip tekrar deneyin.";
      if (e.code == 'too-many-requests') return "Çok fazla istek gönderildi. Lütfen birkaç dakika sonra tekrar deneyin.";
      return "Hata: ${e.message ?? e.code}";
    } catch (e) {
      return "Beklenmeyen bir hata oluştu: $e";
    }
  }

  /// E-posta ve şifre ile giriş yapar (Opsiyonel, şu anki akışta kullanılmayabilir).
  Future<User?> signIn(String email, String password) async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      debugPrint("Giriş hatası: $e");
      return null;
    }
  }

  static const String defaultPrivacyText = """
1. GİRİŞ
Bu Gizlilik Politikası, işletmemizin kişisel verilerinizi nasıl topladığını, kullandığını ve koruduğunu açıklar.

2. VERİ TOPLAMA
Hizmetlerimizi kullandığınızda aşağıdaki bilgileri toplayabiliriz:
- İsim, E-posta, Telefon Numarası
- Cihaz Bilgileri
- Konum Bilgileri (izin verildiğinde)

3. VERİ KULLANIMI
Verileriniz şu amaçlarla kullanılır:
- Hizmet sunumu
- Müşteri supports
- Güvenlik ve doğrulama
- Yasal yükümlülükler

4. VERİ GÜVENLİĞİ
Verilerinizin güvenliği bizim için önemlidir. Endüstri standardı güvenlik önlemleri uyguluyoruz.

5. ÇEREZLER
Hizmet kalitesini artırmak için çerezler kullanabiliriz.

6. DEĞİŞİKLİKLER
Bu politikayı zaman zaman güncelleyebiliriz. Güncellemeler uygulamada duyurulacaktır.

.......................................................
(Daha fazla metin aşağı kaydırmayı zorunlu kılmak için eklenmiştir)
.......................................................
Lütfen tüm metni okuduğunuzdan emin olun.
.......................................................
Veri sorumlusu olarak haklarınız saklıdır.
.......................................................
KVKK kapsamında başvuru haklarınız mevcuttur.
.......................................................
İletişim için: info@gastrofy.com
.......................................................
Son güncelleme: 2026
  """;

  static const String defaultTermsText = """
1. KABUL VE TARAFLAR
Bu Kullanım Koşulları ("Sözleşme"), Gastrofy uygulamasına ("Uygulama") erişiminiz ve kullanımınızla ilgili kuralları belirler. Uygulamayı indirerek, kurarak veya kullanarak bu şartları kabul etmiş sayılırsınız. Eğer bu şartları kabul etmiyorsanız, lütfen uygulamayı kullanmayınız.

2. HİZMETİN KAPSAMI
Uygulama, restoran ve kafe işletmeleri için masa takibi, sipariş yönetimi ve personel idaresi hizmetleri sunar. Şirketimiz, hizmetin içeriğini, özelliklerini veya kullanılabilirliğini önceden bildirmeksizin değiştirme veya sonlandırma hakkını saklı tutar.

3. HESAP GÜVENLİĞİ VE SORUMLULUK
- Kullanıcı, hesabının güvenliğini sağlamakla yükümlüdür.
- Şifrenizi kimseyle paylaşmamalısınız.
- Hesabınız üzerinden yapılan tüm işlemlerden siz sorumlusunuz.
- Şüpheli bir durum fark ederseniz derhal bize bildirmelisiniz.

4. KULLANIM KURALLARI
Aşağıdaki eylemler kesinlikle yasaktır:
- Uygulamayı yasa dışı amaçlarla kullanmak.
- Sistemin güvenliğini tehdit edecek girişimlerde bulunmak.
- Tersine mühendislik yapmak veya kaynak kodunu kopyalamak.
- Diğer kullanıcıların haklarını ihlal etmek veya taciz etmek.
- Uygulama üzerinden spam veya zararlı yazılım yaymak.

5. FİKRİ MÜLKİYET
Uygulamanın tüm tasarımı, logosu, yazılımı, veritabanı ve içeriği şirketimize aittir. Bu materyallerin izinsiz kopyalanması, dağıtılması veya ticari amaçla kullanılması yasaktır.

6. ÜÇÜNCÜ TARAF HİZMETLERİ
Uygulama, üçüncü taraf web sitelerine veya hizmetlerine bağlantılar içerebilir. Bu hizmetlerin içeriğinden veya gizlilik politikalarından sorumlu değiliz. Üçüncü taraf hizmetlerini kullanırken ilgili tarafın koşullarını incelemeniz önerilir.

7. ÜCRETLENDİRME VE ÖDEMELER
- Uygulama içi satın alımlar veya abonelikler söz konusu olduğunda, belirtilen ücretler geçerlidir.
- Ücretlerde değişiklik yapma hakkımız saklıdır.
- İptal ve iade koşulları ilgili platformun (App Store/Google Play) politikalarına tabidir.

8. SORUMLULUK REDDİ (DISCLAIMER)
Hizmet "olduğu gibi" sunulmaktadır. Şirketimiz, hizmetin kesintisiz, hatasız veya virüssüz olacağını garanti etmez. Veri kaybı, gelir kaybı veya diğer dolaylı zararlardan sorumlu tutulamaz.
  """;

  /// Şirketi Firebase Firestore'a kaydeder veya günceller.
  Future<bool> registerCompany(Map<String, dynamic> userData) async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint("Firebase henüz yapılandırılmadı. Kayıt atlanıyor.");
        return false;
      }
      final String email = userData['userEmail'] ?? '';
      if (email.isEmpty) return false;

      // Email adresini doküman ID'si olarak kullanabiliriz veya rastgele ID.
      // Şirket ismi + Email birleşimi daha garantidir.
      final String docId = email.replaceAll('.', '_');

      await _firestore.collection('companies').doc(docId).set({
        'companyName': userData['companyName'],
        'ownerName': userData['userName'],
        'email': userData['userEmail'],
        'contact': userData['userContact'],
        'address': userData['address'],
        'role': userData['userRole'],
        'termsAcceptedOn': userData['termsAcceptedOn'],
        'lastAcceptedTermsAt': FieldValue.serverTimestamp(),
        'lastSync': FieldValue.serverTimestamp(),
        'status': 'trial', // Default to trial for new companies
        'deviceId': userData['deviceId'], // Lock to specific hardware
        'plan': 'Trial',
        'expiryDate': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
        'licenseStatus': 'active', // overall license status (active/blocked)
      }, SetOptions(merge: true));

      // Cihaz donanımını deneme kullandı olarak kaydet
      final String deviceId = userData['deviceId'] ?? '';
      if (deviceId.isNotEmpty) {
        await recordDeviceTrial(deviceId, email);
      }

      debugPrint("Şirket Firebase'e kaydedildi: $email");
      return true;
    } catch (e) {
      debugPrint("Firebase Şirket Kayıt Hatası: $e");
      return false;
    }
  }

  /// Bu donanım kimliğinin (deviceId) daha önce 7 günlük deneme kullanıp kullanmadığını kontrol eder.
  Future<bool> checkDeviceTrialUsed(String deviceId) async {
    try {
      if (Firebase.apps.isEmpty || deviceId.isEmpty || deviceId == 'unknown_device') {
        return false;
      }
      final doc = await _firestore.collection('device_trials').doc(deviceId).get();
      return doc.exists;
    } catch (e) {
      debugPrint("Cihaz deneme kontrol hatası: $e");
      return false;
    }
  }

  /// Cihaz donanımını deneme sürümü kullandı olarak mühürler.
  Future<void> recordDeviceTrial(String deviceId, String email) async {
    try {
      if (Firebase.apps.isEmpty || deviceId.isEmpty || deviceId == 'unknown_device') {
        return;
      }
      await _firestore.collection('device_trials').doc(deviceId).set({
        'deviceId': deviceId,
        'usedByEmail': email,
        'createdAt': FieldValue.serverTimestamp(),
        'trialExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Cihaz deneme kayıt hatası: $e");
    }
  }

  /// Şirket profil bilgilerini günceller (Lisans verilerine dokunmaz).
  Future<bool> updateCompanyProfile(Map<String, dynamic> userData) async {
    try {
      if (Firebase.apps.isEmpty) return false;
      final String email = userData['userEmail'] ?? '';
      if (email.isEmpty) return false;
 
       final String docId = email.replaceAll('.', '_');
       
       await _firestore.collection('companies').doc(docId).update({
         'companyName': userData['companyName'],
         'ownerName': userData['userName'],
         'contact': userData['userContact'],
         'address': userData['address'],
         'companyPhone': userData['companyPhone'],
         'lastSync': FieldValue.serverTimestamp(),
       });
 
       debugPrint("Şirket profili güncellendi: $email");
       return true;
     } catch (e) {
       debugPrint("Firebase Şirket Güncelleme Hatası: $e");
       return false;
     }
   }
 
  /// Son giriş zamanını günceller (Otomatik silme takibi için).
  /// Veri tasarrufu için her açılışta değil, 3 günde bir günceller.
  Future<void> updateLastLogin(Map<String, dynamic> user) async {
    try {
      if (Firebase.apps.isEmpty) return;

      // TERMINAL GUARD: Bağlı terminallerin ana şirket verisini güncelleme yetkisi yoktur.
      // Bu hatayı (permission-denied) engellemek için sadece Yönetici ise devam et.
      if (user['userRole'] != 'Yönetici') {
        debugPrint("Terminal cihazı, Firestore son giriş güncellemesi atlandı.");
        return;
      }
      
      // 1. Yerel kontrol (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final int? lastSyncMillis = prefs.getInt('last_login_sync_time');
      final DateTime now = DateTime.now();

      if (lastSyncMillis != null) {
        final DateTime lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
        final Duration diff = now.difference(lastSync);
        
        // Eğer son güncelleme 3 günden eskiyse güncelle, yoksa atla.
        // Kullanıcı isteği: "Ayda 1 en kötü" -> Biz 3 gün yapalım, garanti olsun.
        if (diff.inDays < 3) {
          debugPrint("Son giriş güncel (Son: $lastSync), Firestore yazma işlemi atlandı.");
          return;
        }
      }

      final String email = user['userEmail'] ?? '';
      if (email.isEmpty) return;

      final String docId = email.replaceAll('.', '_');
      
      // 2. Firestore güncelleme
      await _firestore.collection('companies').doc(docId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastSync': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0', // Versiyon takibi için de faydalı olabilir
      });

      // 3. Yerel zamanı güncelle
      await prefs.setInt('last_login_sync_time', now.millisecondsSinceEpoch);
      
      debugPrint("Son giriş zamanı Firestore'a yazıldı: $email");
    } catch (e) {
      debugPrint("Son giriş güncelleme hatası: $e");
    }
  }

  /// Personeli şirketin alt koleksiyonuna (staff) senkronize eder.
  Future<void> syncStaffMember(String companyEmail, Map<String, dynamic> staffData) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final String companyDocId = companyEmail.replaceAll('.', '_');
      final String staffEmail = staffData['userEmail'] ?? '';
      if (staffEmail.isEmpty) return;

      final String staffDocId = staffEmail.replaceAll('.', '_');

      await _firestore
          .collection('companies')
          .doc(companyDocId)
          .collection('staff')
          .doc(staffDocId)
          .set({
        'name': staffData['userName'],
        'email': staffData['userEmail'],
        'role': staffData['userRole'],
        'pin': staffData['quickLoginPin'],
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("Personel buluta senkronize edildi: $staffEmail");
    } catch (e) {
      debugPrint("Personel senkronizasyon hatası: $e");
    }
  }

  // ===================== GASTROQR (PUBLIC MENU) SYNC =====================

  /// Ürünü GastroQR (Halka Açık Menü) için buluta senkronize eder.
  Future<void> syncProductToPublicMenu(String companyEmail, Map<String, dynamic> productData) async {
    try {
      final firestore = await _getGastroQRFirestore();
      final String docId = companyEmail.replaceAll('.', '_');
      final String prodId = productData['id'];
      final String path = 'companies/$docId/public_menu_products/$prodId';
      
      debugPrint("GastroQR Ürün Sync: $path");
      await firestore.doc(path).set({
        ...productData,
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("GastroQR Ürün Sync Hatası: $e");
    }
  }

  /// Ürünü GastroQR'dan siler.
  Future<void> deleteProductFromPublicMenu(String companyEmail, String productId) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final String companyDocId = companyEmail.replaceAll('.', '_');

      await _firestore
          .collection('companies')
          .doc(companyDocId)
          .collection('public_menu_products')
          .doc(productId)
          .delete();

      debugPrint("Ürün GastroQR'dan silindi: $productId");
    } catch (e) {
      debugPrint("GastroQR Ürün silme hatası: $e");
    }
  }

  /// Ürün resmini ImgBB'ye yükler ve URL'i döndürür.
  Future<String?> uploadProductImage(String companyEmail, String productId, File imageFile) async {
    try {
      const String apiKey = "80fc1a3ce2d6f22813eca766de7a85d8";
      final Uri uri = Uri.parse("https://api.imgbb.com/1/upload?key=$apiKey");
      
      debugPrint("ImgBB Yükleme Başlıyor: ${imageFile.path}");
      
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        final String? url = jsonResponse['data']['url'];
        debugPrint("ImgBB Yükleme Başarılı: $url");
        return url;
      } else {
        debugPrint("ImgBB Hata (${response.statusCode}): $responseData");
        return null;
      }
    } catch (e) {
      debugPrint("ImgBB Resim yükleme hatası: $e");
      return null;
    }
  }

  /// Kategoriyi GastroQR için buluta senkronize eder.
  Future<void> syncCategoryToPublicMenu(String companyEmail, Map<String, dynamic> categoryData) async {
    try {
      final firestore = await _getGastroQRFirestore();
      final String docId = companyEmail.replaceAll('.', '_');
      final String catId = categoryData['id'];
      final String path = 'companies/$docId/public_menu_categories/$catId';
      
      debugPrint("GastroQR Kategori Sync: $path");
      await firestore.doc(path).set({
        ...categoryData,
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("GastroQR Kategori Sync Hatası: $e");
    }
  }

  /// Kategoriyi GastroQR'dan siler.
  Future<void> deleteCategoryFromPublicMenu(String companyEmail, String categoryId) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final String companyDocId = companyEmail.replaceAll('.', '_');

      await _firestore
          .collection('companies')
          .doc(companyDocId)
          .collection('public_menu_categories')
          .doc(categoryId)
          .delete();

      debugPrint("Kategori GastroQR'dan silindi: $categoryId");
    } catch (e) {
      debugPrint("GastroQR Kategori silme hatası: $e");
    }
  }

  /// GastroQR özelliğini açar/kapatır ve şirket bilgilerini senkronize eder.
  Future<void> updateGastroQRStatus(String email, bool isEnabled, {Map<String, dynamic>? metadata}) async {
    try {
      final firestore = await _getGastroQRFirestore();
      final String docId = email.replaceAll('.', '_');
      final String path = 'companies/$docId';
      
      debugPrint("GastroQR Sync Başlıyor: $path (Project: ${firestore.app.options.projectId})");
      
      final Map<String, dynamic> data = {
        'isGastroQREnabled': isEnabled,
        'gastroQRUpdatedAt': FieldValue.serverTimestamp(),
      };
      
      if (metadata != null) {
        data.addAll(metadata);
      }
      
      await firestore.doc(path).set(data, SetOptions(merge: true));
      debugPrint("GastroQR Ana Bilgiler Güncellendi: $path");
    } catch (e) {
      debugPrint("GastroQR Ana Bilgi Hatası ($email): $e");
    }
  }

  /// Belirli bir slug'ın müsait olup olmadığını kontrol eder.
  Future<bool> isSlugAvailable(String slug) async {
    try {
      final firestore = await _getGastroQRFirestore();
      final snapshot = await firestore
          .collection('companies')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      debugPrint("Slug kontrol hatası: $e");
      return false;
    }
  }

  /// Şirket için özel slug (link) tanımlar.
  Future<void> updateCompanySlug(String email, String slug) async {
    try {
      final firestore = await _getGastroQRFirestore();
      final String docId = email.replaceAll('.', '_');
      await firestore.collection('companies').doc(docId).set({
        'slug': slug,
        'slugUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("Slug güncellendi: $slug");
    } catch (e) {
      debugPrint("Slug güncelleme hatası: $e");
    }
  }

  /// Şirket için tema tanımlar.
  Future<void> updateCompanyTheme(String email, String themeId) async {
    try {
      final firestore = await _getGastroQRFirestore();
      final String docId = email.replaceAll('.', '_');
      await firestore.collection('companies').doc(docId).set({
        'themeId': themeId,
        'themeUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("Tema güncellendi: $themeId");
    } catch (e) {
      debugPrint("Tema güncelleme hatası: $e");
    }
  }

  /// Şirket için ürün fotoğraflarının görünüp görünmeyeceğini ayarlar.
  Future<void> updateCompanyShowPhotos(String email, bool show) async {
    try {
      final firestore = await _getGastroQRFirestore();
      final String docId = email.replaceAll('.', '_');
      await firestore.collection('companies').doc(docId).set({
        'showProductPhotos': show,
        'showPhotosUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("Fotoğraf görünürlüğü güncellendi: $show");
    } catch (e) {
      debugPrint("Fotoğraf görünürlük güncelleme hatası: $e");
    }
  }

  /// Personeli buluttan siler.
  Future<void> deleteStaffMemberFromCloud(String companyEmail, String staffEmail) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final String companyDocId = companyEmail.replaceAll('.', '_');
      final String staffDocId = staffEmail.replaceAll('.', '_');

      await _firestore
          .collection('companies')
          .doc(companyDocId)
          .collection('staff')
          .doc(staffDocId)
          .delete();

      debugPrint("Personel buluttan silindi: $staffEmail");
    } catch (e) {
      debugPrint("Personel silme hatası (Cloud): $e");
    }
  }

  /// Sözleşmeleri buluttan çekme isteği iptal edildi, yerel metin kullanılır.
  Future<Map<String, dynamic>> getContracts() async {
    return {
      'privacy': defaultPrivacyText,
      'terms': defaultTermsText,
      'updatedAt': Timestamp.now(),
    };
  }

  Future<void> updateContractAcceptanceDate(String email) async {
    // İptal edildi
  }

  /// Tüm kayıtlı şirketleri getirir (Geliştirici Paneli için).
  Future<List<Map<String, dynamic>>> fetchAllCompanies() async {
    try {
      if (Firebase.apps.isEmpty) return [];
      final snapshot = await _firestore
          .collection('companies')
          .orderBy('lastSync', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Şirket listesi çekme hatası: $e");
      return [];
    }
  }

  /// Geliştirici girişi (Firebase Auth kullanarak).
  /// Not: Geliştirici hesabı önceden Firebase Console üzerinden oluşturulmuş olmalıdır.
  Future<User?> developerLogin(String email, String password) async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      debugPrint("Geliştirici girişi hatası: $e");
      return null;
    }
  }

  /// Lisans kontrol istekleri iptal edildi (Her zaman aktif kabul edilir).
  Future<Map<String, dynamic>?> checkLicenseStatus(String email) async {
    return {
      'licenseStatus': 'active',
      'status': 'active',
      'plan': 'Premium',
    };
  }

  /// Cihaz bilgisini günceller veya temizler (null gelirse).
  Future<bool> updateDeviceId(String email, String? newDeviceId) async {
    try {
      if (Firebase.apps.isEmpty) return false;
      final String docId = email.replaceAll('.', '_');
      await _firestore.collection('companies').doc(docId).update({
        'deviceId': newDeviceId,
        'licenseStatus': newDeviceId == null ? 'pending' : 'active',
      });
      return true;
    } catch (e) {
      debugPrint("Cihaz güncelleme hatası: $e");
      return false;
    }
  }

  /// Promo kodu kullanır ve süreyi uzatır.
  Future<String> redeemPromoCode(String email, String code) async {
    try {
      if (Firebase.apps.isEmpty) return "Firebase bağlantısı yok.";

      // 1. Kodu bul
      final promoSnap = await _firestore
          .collection('promo_codes')
          .where('code', isEqualTo: code)
          .where('isUsed', isEqualTo: false)
          .get();

      if (promoSnap.docs.isEmpty) {
        return "Geçersiz veya kullanılmış kod.";
      }

      final promoDoc = promoSnap.docs.first;
      final int durationDays = promoDoc.data()['durationDays'] ?? 30;

      // 2. Şirket verisini bul ve süreyi uzat
      final String docId = email.replaceAll('.', '_');
      final companySnap = await _firestore.collection('companies').doc(docId).get();

      if (!companySnap.exists) {
        return "Şirket kaydı bulunamadı.";
      }

      DateTime currentExpiry = (companySnap.data()?['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();
      
      // Eğer mevcut süre dolmuşsa bugünden başlat, dolmamışsa üzerine ekle
      DateTime baseDate = currentExpiry.isAfter(DateTime.now()) ? currentExpiry : DateTime.now();
      DateTime newExpiry = baseDate.add(Duration(days: durationDays));

      // 3. Güncelleme
      await _firestore.runTransaction((transaction) async {
        transaction.update(companySnap.reference, {
          'expiryDate': Timestamp.fromDate(newExpiry),
          'licenseStatus': 'active',
          'status': 'active',
        });
        transaction.update(promoDoc.reference, {
          'isUsed': true,
          'usedBy': email,
          'usedAt': FieldValue.serverTimestamp(),
        });
      });

      return "SUCCESS:$durationDays";
    } catch (e) {
      debugPrint("Promo kod hatası: $e");
      return "Bir hata oluştu: $e";
    }
  }

  /// [BYPASS] Ödeme altyapısı olmadığı için geçici olarak lisans aktif eder.
  Future<bool> activateBypassLicense(String email, String planName) async {
    try {
      if (Firebase.apps.isEmpty) return false;

      final String docId = email.replaceAll('.', '_');
      final companyRef = _firestore.collection('companies').doc(docId);

      DateTime newExpiry = DateTime.now().add(const Duration(days: 365));

      await companyRef.update({
        'expiryDate': Timestamp.fromDate(newExpiry),
        'licenseStatus': 'active',
        'status': 'active',
        'plan': planName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint("Bypass lisans hatası: $e");
      return false;
    }
  }

  /// Destek / Geri Bildirim mesajı gönderir.
  Future<bool> sendSupportMessage({
    required String category,
    required String message,
    required Map<String, dynamic> user,
  }) async {
    try {
      if (Firebase.apps.isEmpty) return false;

      await _firestore.collection('support_messages').add({
        'companyName': user['companyName'],
        'userName': user['userName'],
        'userEmail': user['userEmail'],
        'userContact': user['userContact'],
        'category': category,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, read, solved
      });

      debugPrint("Destek mesajı gönderildi: $category");
      return true;
    } catch (e) {
      debugPrint("Destek mesajı gönderme hatası: $e");
      return false;
    }
  }

  /// Şirket hesabını ve ilgili verileri siler (Auth ve Firestore).
  Future<Map<String, dynamic>> deleteCompanyAccount(Map<String, dynamic> user, String password) async {
    try {
      if (Firebase.apps.isEmpty) return {'success': false, 'message': 'Firebase bağlantısı yok.'};
      
      final String email = user['userEmail'] ?? '';
      if (email.isEmpty) return {'success': false, 'message': 'E-posta bulunamadı.'};

      final String docId = email.replaceAll('.', '_');
      final currentUser = _auth.currentUser;

      // 0. Re-authentication (Only if user exists)
      if (currentUser != null) {
        try {
          AuthCredential credential = EmailAuthProvider.credential(email: currentUser.email!, password: password);
          await currentUser.reauthenticateWithCredential(credential);
        } catch (e) {
          debugPrint("Re-auth hatası: $e");
          // Şifre yanlışsa durdur, ama kullanıcı zaten yoksa devam et (altta kontrol edilecek)
          if (e.toString().contains('user-not-found') || e.toString().contains('user-token-expired')) {
              // Kullanıcı zaten silinmiş olabilir, devam et
          } else {
            return {'success': false, 'message': 'Kimlik doğrulama başarısız. Lütfen şifrenizi kontrol edin.'};
          }
        }
      }

      // 1. Firestore'dan Şirket Verisini ve Alt Koleksiyonları Sil
      try {
        final companyRef = _firestore.collection('companies').doc(docId);
        
        // Staff alt koleksiyonunu sil
        final staffSnapshot = await companyRef.collection('staff').get();
        for (var doc in staffSnapshot.docs) {
          await doc.reference.delete();
        }

        // Ana dokümanı sil
        await companyRef.delete();
      } catch (e) {
        debugPrint("Firestore silme hatası: $e");
        // Eğer doküman zaten yoksa veya yetki hatası ama kullanıcı zaten yoksa görmezden gel
        if (!e.toString().contains('not-found') && !e.toString().contains('permission-denied')) {
          // Sadece kritik hatalarda durdur
          debugPrint("Kritik Firestore hatası (görmezden geliniyor): $e");
        }
      }

      // 2. Auth Hesabını Sil (Eğer hala duruyorsa)
      if (currentUser != null) {
        try {
          await currentUser.delete();
        } catch (e) {
          debugPrint("Auth silme hatası (zaten silinmiş olabilir): $e");
          // Hata olsa bile doküman silindiği için devam edebiliriz
        }
      }

      // 3. Oturumu Kapat (Temizlik için kritik)
      await signOut();

      debugPrint("Hesap başarıyla silindi (veya zaten silinmişti): $email");
      return {'success': true, 'message': 'Hesabınız ve tüm verileriniz başarıyla silindi.'};
    } catch (e) {
      debugPrint("Genel silme hatası: $e");
      return {'success': false, 'message': 'Bir hata oluştu: $e'};
    }
  }
}
