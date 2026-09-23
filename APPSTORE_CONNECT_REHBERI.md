# 🚀 Gastrofy - App Store Connect Yayın Öncesi Doldurma Rehberi

Bu rehber, **Gastrofy (v3.0.1)** uygulamasını Apple App Store Connect'e yüklerken ve yayına gönderirken doldurmanız gereken **tüm alanları, metinleri, ürün kimliklerini (ID) ve gizlilik ayarlarını** eksiksiz ve kopyala-yapıştır yapabileceğiniz şekilde içerir.

---

## 📌 1. Genel Uygulama Bilgileri (App Information)

| Alan Adı | Doldurulacak Değer / Öneri | Notlar |
| :--- | :--- | :--- |
| **Uygulama Adı (Name)** | `Gastrofy - Restoran & Masa POS` | Maksimum 30 karakter. Arama sonuçlarında öne çıkarır. |
| **Alt Başlık (Subtitle)** | `Akıllı Masa ve Adisyon Sistemi` | Maksimum 30 karakter. |
| **Birincil Dil (Primary Language)** | `Türkçe` | Varsayılan mağaza dili. |
| **Paket Kimliği (Bundle ID)** | `com.gastromind.app` | Xcode projenizdeki tanımlı kimlik. |
| **SKU** | `gastrofy_pos_app` | Size özel dahili takip kodu (Kullanıcılar görmez). |
| **Birincil Kategori** | `İş (Business)` | En uygun kategori. |
| **İkincil Kategori (Opsiyonel)** | `Yiyecek ve İçecek (Food & Drink)` | İsteğe bağlı alternatif. |
| **İçerik Derecelendirmesi (Age Rating)** | `4+ (Tüm Yaş Grupları)` | Şiddet, kumar vb. içermez olarak işaretleyin. |

---

## 💳 2. Uygulama İçi Satın Alma & Abonelikler (In-App Purchases)

Gastrofy uygulamasında kodlanmış olan iki adet **Otomatik Yenilenen Abonelik (Auto-Renewable Subscription)** bulunmaktadır.

App Store Connect'te sol menüden **"Subscriptions" (Abonelikler)** bölümüne gidip bir **Abonelik Grubu** oluşturun:
* **Grup Adı:** `Gastrofy Planları`

Ardından bu grubun içine aşağıdaki **2 ürünü** ekleyin:

### Ürün 1: Aylık Plan
* **Referans Adı:** `Gastrofy Aylık Plan`
* **Ürün Kimliği (Product ID):** `gastrofy_monthly_299` *(Koddaki ile birebir aynı olmalıdır)*
* **Abonelik Süresi:** `1 Ay (1 Month)`
* **Fiyat:** `₺299,00 / Ay` (veya denk gelen Tier / Fiyat Katmanı)
* **Görüntülenen Ad (Display Name):** `Aylık Plan`
* **Açıklama (Description):** `Tüm masa, sipariş, adisyon ve işletme yönetim özelliklerine 1 ay boyunca sınırsız erişim.`

### Ürün 2: Yıllık Plan
* **Referans Adı:** `Gastrofy Yıllık Plan`
* **Ürün Kimliği (Product ID):** `gastrofy_annual_2990` *(Koddaki ile birebir aynı olmalıdır)*
* **Abonelik Süresi:** `1 Yıl (1 Year)`
* **Fiyat:** `₺2.990,00 / Yıl` (veya denk gelen Tier / Fiyat Katmanı)
* **Görüntülenen Ad (Display Name):** `Yıllık Plan (Table Intelligence)`
* **Açıklama (Description):** `Table Intelligence yapay zeka danışmanı, ciro tahminleri ve tüm özelliklere 1 yıl sınırsız erişim (2 Ay Hediye).`

> **Önemli İpucu (App Store İncelemesi İçin):**
> Her iki abonelik için de ekran görüntüsü (Review Screenshot) yüklemeniz istenecektir. Uygulamanızdaki **"Abonelik Planları"** ekranının ekran görüntüsünü alıp buraya yükleyin.

---

## 🔒 3. Uygulama Gizliliği (App Privacy / Besin Etiketi)

App Store Connect'teki **"App Privacy" (Uygulama Gizliliği)** anketinde şu yanıtları verin:

### 1. Veri Toplama Sorusu
* **"Bu uygulamadan veri topluyor musunuz?"** ➡️ **Evet (Yes)**

### 2. Toplanan Veri Türleri ve Amaçları:
* **İletişim Bilgileri (Contact Info):**
  * Toplanan: `E-posta Adresi (Email Address)`, `İsim (Name)`
  * Amaç: `Uygulama İşlevselliği (App Functionality)` (Giriş yapma, lisans bağlama ve profil yönetimi).
  * Kullanıcıyla İlişkilendiriliyor mu?: `Evet (Yes)`
  * Takip (Tracking) Amaçlı mı?: `Hayır (No)`

* **Kullanıcı İçeriği (User Content):**
  * Toplanan: `Fotoğraflar / Videolar (Photos or Videos)`
  * Amaç: `Uygulama İşlevselliği (App Functionality)` (Ürün menüsü fotoğrafları ve profil görseli yükleme).
  * Kullanıcıyla İlişkilendiriliyor mu?: `Evet (Yes)`
  * Takip Amaçlı mı?: `Hayır (No)`

* **Satın Alma Verileri (Purchases):**
  * Toplanan: `Satın Alma Geçmişi (Purchase History)`
  * Amaç: `Uygulama İşlevselliği (App Functionality)` (Abonelik durumunu doğrulama).
  * Kullanıcıyla İlişkilendiriliyor mu?: `Evet (Yes)`
  * Takip Amaçlı mı?: `Hayır (No)`

### 3. Kullanıcı Takibi (Tracking):
* **"Uygulamanız kullanıcıları diğer şirketlerin uygulamalarında takip ediyor mu?"** ➡️ **HAYIR (No)**

---

## 📱 4. iOS Sistem İzinleri (Info.plist Gerekçeleri)

Uygulamanızda tanımlı izinler ve Apple'ın kullanıcıya göstereceği gerekçeler:

| İzin Anahtarı | Açıklama / Gerekçe |
| :--- | :--- |
| **Kamera (`NSCameraUsageDescription`)** | Masa QR kodlarını okutmak, personel cihazlarını eşleştirmek ve menü ürün fotoğrafları çekmek için kamera erişimi gereklidir. |
| **Fotoğraf Galerisi (`NSPhotoLibraryUsageDescription`)** | Menü ürünlerine ve işletme profiline görsel yükleyebilmek için fotoğraf galerinize erişim gereklidir. |
| **Fotoğraf Kaydetme (`NSPhotoLibraryAddUsageDescription`)** | Oluşturulan satış raporlarını, makbuzları ve QR kod görsellerini galerinize kaydedebilmek için izin gereklidir. |
| **Mikrofon (`NSMicrophoneUsageDescription`)** | Medya kaydı sırasında ses alabilmek için mikrofon erişimi gereklidir. |
| **Yerel Ağ (`NSLocalNetworkUsageDescription`)** | Kasa ve garson cihazları arasında yerel Wi-Fi ağı üzerinden anlık masa ve sipariş senkronizasyonu sağlamak için yerel ağ izni gereklidir. |
| **Konum (`NSLocationWhenInUseUsageDescription`)** | Yerel Wi-Fi ağ bağlantısını tespit etmek ve cihazlar arası senkronizasyon ağını doğrulamak için konum izni gereklidir. |

---

## 📝 5. Sürüm 3.0.1 Bilgileri (Version Information)

### Açıklama (Description)
*(Aşağıdaki metni kopyalayıp App Store Connect'teki Açıklama kutusuna yapıştırabilirsiniz)*

```text
Gastrofy, restoranlar, kafeler, pastaneler ve gastronomi işletmeleri için geliştirilmiş yeni nesil akıllı masa ve sipariş yönetim sistemidir. 

Gastrofy ile işletmenizin tüm süreçlerini tablet ve telefonunuzdan kolayca kontrol edin, servis hızınızı artırın ve cironuzu katlayın!

ÖNE ÇIKAN ÖZELLİKLER:

• Canlı Masa & Adisyon Yönetimi: Masaların anlık durumunu (dolu, boş, rezerve, hesap istendi) tek ekrandan izleyin. Hızlı adisyon açın, ürün ekleyin ve parça ödeme alın.
• Hızlı Satış Modu: Gel-al ve paket servis siparişlerini beklemeden, saniyeler içinde tamamlayın.
• Table Intelligence (Yapay Zeka Analitiği): Ciro trendlerinizi, en çok kazandıran masalarınızı ve çok satan menü kombinasyonlarını yapay zeka desteğiyle analiz edin.
• Gelişmiş Ürün & Kategori Menüsü: Fotoğraflı menü ürünleri, porsiyon seçenekleri ve kategori filtreleriyle hızlı sipariş alma.
• Detaylı Raporlar ve PDF Çıktısı: Günlük ciro, saatlik yoğunluk grafikleri, garson performansları ve veresiye takibi. Raporları anında PDF formatında paylaşın veya yazdırın.
• Hızlı & Güvenli Profil Geçişi: Personel PIN kodu veya Hızlı Giriş ile tek dokunuşla garson/kasa profilleri arasında geçiş yapın.
• Yerel Ağ ile Cihaz Eşleştirme: Kasa tableti ile servis personeli cihazlarını yerel Wi-Fi üzerinden kablosuz olarak anlık senkronize edin.

Gastrofy ile işletmenizin kontrolünü elinize alın, karmaşık sistemlerden kurtulun!
```

### Anahtar Kelimeler / Arama Terimleri (Keywords)
*(Maksimum 100 karakter, aralara virgül koyarak yapıştırın)*
```text
adisyon,pos sistemi,restoran,masa takip,kafe,sipariş,kasa,menü,gastrofy,hesap,veresiye
```

### Bağlantılar (Gerçek GitHub Pages Canlı Bağlantıları)
* **Destek URL (Support URL):** `https://tekneenes.github.io/gastrofy/support.html`
* **Pazarlama URL (Marketing URL):** `https://tekneenes.github.io/gastrofy/`
* **Gizlilik Politikası URL (Privacy Policy URL):** `https://tekneenes.github.io/gastrofy/privacy.html` *(App Store Zorunlu)*
* **Kullanım Koşulları (EULA):** `https://tekneenes.github.io/gastrofy/terms.html` *(Abonelikler için Zorunlu)*

### Telif Hakkı (Copyright)
```text
© 2026 Gastrofy. Tüm Hakları Saklıdır.
```

---

## 🔍 6. İnceleme Ekibi Bilgileri (App Review Information)

Apple inceleme uzmanlarının (Reviewer) uygulamaya giriş yapabilmesi için:

* **Oturum Açma Gerekli (Sign-in required):** `İşaretleyin (Checked)`
* **Kullanıcı Adı (Demo Email):** `demo_user@gastrofy.com` *(veya test için oluşturduğunuz yönetici e-postası)*
* **Şifre:** `123456` *(veya belirlediğiniz demo şifre)*
* **PIN (Gerekirse):** `123456`

### İnceleme Notları (Notes for Reviewer)
*(İnceleyicinin hızlı onay vermesi için bu notu ekleyin)*

```text
Hello App Review Team,

This app is designed for restaurant staff and managers. 
- You can test the application using the demo account credentials provided above.
- In-App Purchases are available in the Subscription screen to unlock annual plan analytics (Table Intelligence).
- iPad experience is strictly optimized for landscape orientation (cash register & tablet mode).
- Local network permissions are used for peer-to-peer Wi-Fi order synchronization between terminal devices.

Thank you!
```

* **İletişim Bilgileri (Contact Info):** Kendi adınız, soyadınız, telefon numaranız (+90...) ve e-posta adresiniz.

---

## 🖼️ 7. Ekran Görüntüleri Boyutları (Screenshots)

App Store Connect'e yüklemeniz gereken ekran görüntüleri:

1. **iPad Ekran Görüntüleri (Zorunlu - Yatay / Landscape):**
   * **13 inç iPad Pro:** `2752 x 2064` piksel veya `2732 x 2048` piksel.
   * **Önerilen Ekranlar:** Masalar ekranı, Adisyon / Masa Detay ekranı, Raporlar ekranı, Hızlı Satış ekranı.
2. **iPhone Ekran Görüntüleri (İsteğe Bağlı/Zorunlu - Dikey / Portrait):**
   * **6.7 inç iPhone (15 Pro Max / 16 Pro Max):** `1290 x 2796` piksel.
   * **6.5 inç iPhone:** `1242 x 2688` piksel.
