# AI_LOG — UstaRota

Bu dosya, projenin AI ile nasıl üretildiğini, hangi kararları benim verdiğimi, hangi AI
önerilerini kabul ettiğimi ya da değiştirdiğimi ve sonucu nasıl doğruladığımı anlatır.
Yalnızca gerçekten olanları yazdım. Bulunmayan bir hata uydurmadım.

## Süre

| | |
|---|---|
| Platformda çalışmayı başlatma | Daha önce (24 saatlik pencere o an başladı) |
| Üretime başlama (AI'a ilk mesaj) | 2026-10-10 22:24 (TSİ) |
| Teslim | _teslimde doldurulacak_ |

## Araçlar

| Araç | Ne için |
|---|---|
| **Claude Code** (masaüstü uygulaması, model: Claude Opus 5.5) | Tek AI aracı. Kod, test ve doküman taslakları; uygulama içi tarayıcıyla arayüz testleri |
| Dart SDK 3.13 (`dart analyze`, `dart test`) | Statik analiz ve otomatik testler |
| Neon (Postgres), Render, GitHub | Veritabanı, barındırma, kaynak kod |

Ücretli ek araç, şablon veya kod üreteci kullanmadım.

## Görev dağılımı

| Ben | AI (Claude Code) |
|---|---|
| Ürün fikri (UstaRota), hedef kitle ve form alanları | Seçilen fikre göre sayfa metni ve kod |
| Teknoloji seçiminin onayı | Seçenekleri ve artı/eksilerini çıkarma |
| Hesaplar, gizli bilgiler (Neon adresi, şifre sıfırlama), GitHub girişi | Gizli bilgiyi koda değil `.env` / ortam değişkenine koyma |
| AI önerilerine itiraz / yön değiştirme | Testleri yazma ve çalıştırma, tarayıcıda senaryoları deneme |

## Kronoloji ve kararlar

### 1. Teknoloji seçimi — AI önerisini değiştirdim, sonra yeni öneriyi kabul ettim
- **AI'ın ilk önerisi:** Next.js + Vercel + Neon.
- **Benim sorum:** Flutter'da yetkinim, Flutter Web ile mi yapalım?
- **AI'ın yanıtı:** Landing page için Flutter Web'i önermedi. Canvas'a çizim yaptığı için erişilebilirliği zayıf, başlangıç paketi büyük, mobilde ilk açılış yavaş ve arama motorları içeriği okuyamıyor. Yerine **düz HTML/CSS/JS ön yüz ve Dart (shelf) backend** önerdi: sunucu ve güvenlik kodu benim bildiğim dilde olsun.
- **Karar:** Bunu kabul ettim. Bedeli doğrulama kurallarının iki dilde (JS ve Dart) yazılması; bunu README'de bilinen eksik olarak yazdım.
- _Benim gerekçem: **[KENDİ CÜMLENLE DOLDUR]**_

### 2. Konu — kendi fikrime geçtim
- **AI'ın ilk önerisi ve ilk uygulama:** KOBİ'ler için görev otomasyonu ("Akışkan"). Sayfa ve backend bu konuyla yazılıp test edildi.
- **Benim ilk yönlendirmem:** Gerçek bir sitenin (magazacepte.com) formunu temel almak, telefon ve ad soyad toplamak.
- **AI'ın itirazı:** Case **kurgusal** hizmet ve **kurgusal test verisi** istiyor; gerçek bir markayı kullanmak bu şartı bozar. Case'in zorunlu alanları (isim, e-posta, hizmet, açıklama) ile ad soyad + telefon formu uyuşmuyor. Gerçek telefon toplamak KVKK yükümlülüğü getirir.
- **Karar (benim):** Gerçek siteyi kullanmak yerine kendi kurgusal fikrime geçtim: **UstaRota**. Tesisatçı, elektrikçi gibi hizmet verenlerin kayıt olduğu, işlerin onlara taksi gibi yönlendirildiği bir aracı platform. Form: e-posta, 10 hizmetten biri, 20–200 karakter iş açıklaması.
- _Benim gerekçem:_ Kendi düşüncem olduğu için, anlık olarak daha iyi bir şey çıkabileceğini düşündüm.
- **AI'ın düzeltmesi, kabul ettim:** Case "isim" alanını zorunlu tuttuğu için ad soyad alanını korudu.
- **Teknik sonuç:** Hizmet listesi ve karakter sınırları tek dosyada (`validation.dart`) tutuluyor. Veritabanındaki `CHECK` kısıtları da bu sabitlerden üretiliyor, böylece konu değişince iki liste birbirinden kopmadı.

### 3. Git kimliği — benim kararım
- **AI'ın tespiti:** Global git ayarında eski işyerimin e-posta adresi vardı. Commit'ler başka bir şirkete yapılan başvuruda bu adresle görünecekti.
- **Karar:** Eski şirketle hiçbir ilgisi olmasın dedim. Kişisel e-postam yalnızca bu repoya ayarlandı (`git config` yerel). Global ayara dokunulmadı.

### 4. Neon'un hazır kurulum komutları — reddedildi
- Neon paneli; global CLI, Claude için MCP/skill kurulumu ve `neon deploy` içeren bir komut listesi verdi.
- **AI'ın önerisi, kabul ettim:** Uygulamadık. Bizim ihtiyacımız yalnızca bağlantı adresiydi. Fazladan araç kalıcı ayar değişikliği yapar ve değerlendiricinin kurulumunu uzatır.

### 5. Gizli bilgi sohbete yapıştırıldı — şifre sıfırlandı
- Neon bağlantı adresini (şifre dahil) sohbete yapıştırdım.
- AI, adres sohbet dökümünde kalacağı için şifreyi sıfırlamamı önerdi. **Neon'da şifreyi sıfırladım.**
- Yeni şifreyi sohbete yazmadım: panoya kopyaladım, AI bir PowerShell komutuyla panodan okuyup `.env`'e yazdı (komut değeri ekrana basmadı, yalnızca biçimini kontrol etti). Render'a da kendim girdim.
- **Doğrulama:** Yeni şifreyle `dart run tool/list_leads.dart` çalıştı, önceki kayıtlar okundu.
- **Doğrulanmayan:** Eski şifreyle bağlanmanın reddedildiğini doğrudan denemedim. AI'ın bunu denemek için yazdığı komut, sızmış bir şifreyi kullandığı için Claude Code'un izin sistemi tarafından engellendi. Neon'un şifre sıfırlamasının eski şifreyi geçersiz kılmasına güveniyorum.

### 6. GitHub push 403
- Windows'ta önbellekteki GitHub kimliği farklı bir hesaptı (`AhmetKartalmiss`), push reddedildi.
- AI kayıtlı kimlik bilgilerini silmek yerine remote adresine doğru kullanıcı adını ekledi (`https://AhmetKartalmis@github.com/...`). Doğru hesapla giriş yaptım, push başarılı oldu.

## AI'ın ürettiği koddaki hatalar ve nasıl yakalandıkları

| Sorun | Nasıl bulundu | Düzeltme |
|---|---|---|
| Neon adresindeki `channel_binding=require` parametresi, `postgres` 3.5.20 paketinde `ArgumentError` fırlatıyor; adres olduğu gibi kullanılsa sunucu hiç açılmazdı | Kod yazılmadan önce paketin kaynak kodu (`connection_string.dart`) okundu | `normalizeDatabaseUrl()` yalnızca bu parametreyi çıkarır, `sslmode` korunur. Birim testi + gerçek Neon adresiyle bağlantı testi |
| Bozuk UTF-8 gövdesi `try` bloğunun dışında çözülüyordu → 400 yerine 500 | AI'ın ilk yazımdan sonra kendi kodunu gözden geçirmesi | Okuma ve JSON çözme tek `try` içinde; test: `bozuk JSON ve bozuk UTF-8 400 döner` |
| İstemci IP'si `HttpConnectionInfo.toString()` ile alınıyordu (her istekte aynı anlamsız metin, rate limit tüm kullanıcılar için tek sayaç olurdu) | Aynı gözden geçirme | `remoteAddress.address` |
| Başarı mesajında satır içi stil (`p.style`) | Gözden geçirme | CSS kuralına taşındı (CSP `style-src 'self'` ile tutarlılık) |

Uygulama hatası **olmayan** ama dürüstlük için not ettiğim iki durum:
- İlk `dart test` çalıştırmasında iki test dosyası "yükleme" aşamasında hata verdi. Kod değiştirilmeden tekrar çalıştırıldığında 22/22 geçti; sonraki tüm çalıştırmalarda tekrarlanmadı. İlk derlemeyle ilgili geçici bir durum olduğunu düşünüyorum.
- Tarayıcı testlerinden birinde AI, sayfa kaydıktan sonra eski eleman koordinatlarına tıkladı; metinler yanlış alanlara gitti. Bu, test otomasyonunun hatasıydı. Sayfa yenilenip test tekrarlandı.

## AI'ın sık yaptığı ama burada bilinçli olarak reddedilen öneri

- **Honeypot'a sahte başarı dönmek:** Yaygın bir yöntem, bota "başarılı" deyip kaydı sessizce atmaktır. Case "başarı mesajı yalnızca kayıt başarılı olduğunda" dediği için reddedildi; honeypot dolu istek `400` alır.

## Doğrulama — neyi, nasıl sınadım

### Otomatik (tekrarlanabilir)

```bash
dart analyze          # No issues found
dart test             # 25 geçti, 1 atlandı (TEST_DATABASE_URL yoksa Postgres testi atlanır)
```

| Test | Kanıtladığı |
|---|---|
| `veritabanı hatasında 500 döner, asla başarı dönmez` | Kayıt yoksa başarı yok; log'da kişisel veri yok |
| `geçerli talep 201 döner ve depoya normalize edilmiş halde yazılır` | Mutlu yol, e-posta küçük harfe çevrilir |
| `geçersiz alanlarda 400 ...`, `bozuk JSON ...`, `415`, `413` | Sunucu doğrulaması istemciden bağımsız çalışır |
| `honeypot dolu ise kayıt yapılmaz ve başarı dönmez` | Bot önlemi sahte başarı üretmez |
| `aynı IP sınırı aşınca 429 döner, farklı IP etkilenmez` | Rate limit |
| `yalnızca listedeki hizmetler kabul edilir` (SQL enjeksiyonu denemesi dahil) | İzin listesi |
| `kayıt veritabanına yazılır ve ayrı bir bağlantıdan okunur` | **Gerçek Neon'a karşı** kalıcılık (çalıştırıldı, geçti) |

### Elle (uygulama içi tarayıcı, 375 px mobil ve 1280 px masaüstü)

| Senaryo | Sonuç |
|---|---|
| Boş form gönder | 4 alan `aria-invalid`, odak alanlara bağlantı veren hata özetinde |
| Klavyeyle (Tab + Enter) doldurup gönder | "Gönderiliyor…" (buton kilitli) → "Başvurunuz alındı (başvuru no: N)", form temizlendi |
| 19 karakterlik açıklama | "Açıklama en az 20 karakter olmalı." |
| Veritabanı hatası (`tool/dev_server.dart --fail-db`) | Hata mesajı, başarı yok, 4 alan da korundu |
| Sunucu kapalıyken gönder | "Bağlantı kurulamadı, başvurunuz gönderilmedi", veriler korundu |
| İstemciyi atlayıp `fetch` ile geçersiz veri (`service: "x' OR 1=1--"`) | Sunucu `400` ve alan hataları |
| Konsol / CSP ihlali | Hata yok |
| Yatay kaydırma (mobil ve masaüstü) | Yok |
| **Gerçek sunucu + Neon:** tarayıcıdan başvuru | "başvuru no: 2" → `dart run tool/list_leads.dart` ile kayıt Neon'da görüldü, Türkçe karakterler bozulmamış |

### Canlı ortam (Render)

_Deploy sonrası doldurulacak._

## Bilinen eksikler

README > Bilinen eksikler bölümüne bakın.
