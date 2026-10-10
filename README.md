# UstaRota — hizmet verenler için başvuru sayfası

UstaRota, tesisatçı ve elektrikçi gibi hizmet verenleri yakınlarındaki işlere taksi
çağırır gibi yönlendiren **kurgusal** bir aracı platformdur. Bu repo, hizmet verenlerin
platforma katılmak için başvurduğu landing page'i ve başvuru API'sini içerir.
Form gönderimleri sunucuda
doğrulanır ve Postgres'e kalıcı olarak yazılır. **Başarı mesajı yalnızca kayıt
veritabanına yazıldıktan sonra** gösterilir.

- **Canlı adres:** https://usta-rota.onrender.com
- **Teslim commit'i:** başvuru platformuna bildirilen commit (son commit'in kimliği o an `git log -1` ile alındı)
- **AI çalışma kaydı:** [AI_LOG.md](AI_LOG.md)

> Tüm içerik ve test verileri kurgusaldır; ticari kullanım yoktur.

## Mimari

```
Tarayıcı (public/: HTML + CSS + JS)
   │  POST /api/leads  (JSON)
   ▼
Dart sunucu (shelf) — bin/server.dart, lib/src/
   │  doğrulama → istek sınırı → parametreli INSERT
   ▼
Postgres (Neon) — leads tablosu, CHECK kısıtlarıyla
```

Tek servis hem statik sayfayı hem API'yi sunar (tek deploy, CORS gerekmez).

| Dosya | Görev |
|---|---|
| `public/index.html` | Sayfa içeriği: kime/vaat → ustanın sorunları → nasıl çalışır → hizmetler → başvuru formu |
| `public/app.js` | İstemci doğrulaması, gönderiliyor/başarı/hata durumları |
| `lib/src/validation.dart` | Sunucu doğrulaması (asıl yetki) |
| `lib/src/app.dart` | HTTP rotaları, gövde sınırı, honeypot, rate limit, güvenlik başlıkları |
| `lib/src/lead_repository.dart` | Postgres erişimi ve tablo şeması |
| `tool/dev_server.dart` | Yalnızca yerel arayüz geliştirme için bellek içi sunucu |
| `tool/list_leads.dart` | Veritabanındaki son başvuruları listeler (kalıcılık kontrolü) |

### Neden bu teknolojiler?

- **Dart backend:** En yetkin olduğum dil; güvenlik ve veri akışı kodunu rahat anlatabileyim diye.
- **Flutter Web değil, düz HTML:** Landing page'in hızlı açılması, erişilebilir olması (gerçek `<label>`, klavye, ekran okuyucu) ve arama motorlarınca okunması gerekiyor. Flutter Web canvas'a çizdiği ve büyük bir başlangıç paketi indirdiği için bu ihtiyaçlara uymuyor.
- **Harici Postgres:** Ücretsiz barındırma platformlarında disk geçicidir; SQLite/dosya yeniden başlatmada silinirdi.

## API

`POST /api/leads` — `Content-Type: application/json`

```json
{ "name": "Deneme Usta", "email": "usta@ornek.test", "service": "klima", "message": "8 yıllık tecrübe, kombi bakımı ve arıza onarımı." }
```

| Durum | Anlamı | Gövde |
|---|---|---|
| `201` | Kayıt veritabanına yazıldı | `{"ok":true,"id":42}` |
| `400` | Doğrulama hatası / bozuk JSON / honeypot | `{"ok":false,"errors":{"email":"..."}}` |
| `413` | Gövde 16 KB'tan büyük | `{"ok":false,"errors":{"form":"..."}}` |
| `415` | JSON olmayan içerik türü | 〃 |
| `429` | IP başına 10 dakikada 5 talep aşıldı (`Retry-After`) | 〃 |
| `500` | Veritabanına yazılamadı — **başarı dönülmez** | 〃 |

`service` değerleri (10 hizmet): `tesisat`, `elektrik`, `klima`, `beyazesya`, `boya`, `temizlik`, `nakliyat`, `montaj`, `cilingir`, `bahce`.

### Doğrulama kuralları (istemci ve sunucuda aynı)

| Alan | Kural |
|---|---|
| Ad | Kırpıldıktan sonra 2–100 karakter, kontrol karakteri ve satır sonu yok |
| E-posta | `x@y.zz` biçimi, en fazla 254 karakter, küçük harfe çevrilir |
| Hizmet | Yalnızca yukarıdaki 10 değerden biri (izin listesi) |
| İş açıklaması | 20–200 karakter, satır sonu serbest, diğer kontrol karakterleri yok |

## Güvenlik önlemleri

- **SQL enjeksiyonu:** Tüm sorgular parametreli (`Sql.named` + `@param`), kullanıcı verisi SQL metnine eklenmez.
- **İki katlı doğrulama:** Uygulama doğrulaması + tablodaki `CHECK` kısıtları. Kısıtlar `validation.dart` sabitlerinden üretilir, iki liste birbirinden kopamaz.
- **XSS:** Sunucudan gelen metin DOM'a yalnızca `textContent` ile yazılır; CSP `script-src 'self'` satır içi script'e izin vermez.
- **Gizli bilgi:** `DATABASE_URL` yalnızca ortam değişkeninde; `.env` git'e girmez. Sunucu `DATABASE_URL` olmadan açılmayı reddeder.
- **Kötüye kullanım:** IP başına istek sınırı, 16 KB gövde sınırı, honeypot alanı, çift tıklamaya karşı buton kilidi.
- **Log:** Hata loglarına kişisel veri (ad, e-posta, mesaj) yazılmaz.
- **Başlıklar:** `Content-Security-Policy`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`.

## Erişilebilirlik ve mobil

- Her alanın görünür `<label>`'ı var; hata mesajları `aria-describedby` ile alana bağlı, hatalı alan `aria-invalid`.
- Gönderimde hata varsa odak, alanlara bağlantı veren hata özetine taşınır; durum mesajları `aria-live` ile okunur.
- Belirgin odak çerçevesi (`:focus-visible`), "forma atla" bağlantısı, `prefers-reduced-motion` desteği.
- Renk çiftleri WCAG AA kontrastına göre seçildi; dokunma hedefleri en az 44 px; form yazı tipi 16 px (iOS yakınlaştırmasını engeller).
- Mobil öncelikli CSS; 375 px ve 1280 px'te yatay kaydırma olmadığı kontrol edildi.

## Kurulum

Gereksinim: Dart SDK 3.5+ (Flutter SDK içindeki `dart` da olur).

```bash
dart pub get
cp .env.example .env      # DATABASE_URL değerini doldurun
dart run bin/server.dart  # http://localhost:8080
```

Veritabanı olmadan yalnızca arayüzü denemek için (kayıtlar **kalıcı değildir**):

```bash
dart run tool/dev_server.dart            # normal
dart run tool/dev_server.dart --slow     # "gönderiliyor" durumunu görmek için 3 sn gecikme
dart run tool/dev_server.dart --fail-db  # her kayıt 500 döner: hata durumunu görmek için
```

`leads` tablosu sunucu ilk açıldığında `CREATE TABLE IF NOT EXISTS` ile oluşturulur.

Kayıtların gerçekten veritabanında olduğunu görmek için:

```bash
dart run tool/list_leads.dart      # son 10 başvuru
```

## Testler

```bash
dart analyze
dart test
```

- `test/validation_test.dart` — alan kuralları, sınır değerleri, rate limiter.
- `test/api_test.dart` — HTTP katmanı: 201/400/413/415/429/500, honeypot, güvenlik başlıkları. Veritabanı hatasında **asla 201 dönmediği** ve log'a kişisel veri yazılmadığı test edilir.
- `test/postgres_test.dart` — bağlantı adresi düzeltmesi + gerçek veritabanına yazıp **ayrı bir bağlantıdan geri okuyan** kalıcılık testi. `TEST_DATABASE_URL` yoksa atlanır:

  ```powershell
  $env:TEST_DATABASE_URL = "postgresql://..."; dart test test/postgres_test.dart
  ```

Elle yapılan uçtan uca kontroller [AI_LOG.md](AI_LOG.md) içinde listelenmiştir.

## Deploy (Render + Neon)

1. Neon'da proje oluşturup bağlantı adresini alın.
2. Render → New → Web Service → bu repo → Runtime: **Docker**, Instance: Free.
3. Environment'a `DATABASE_URL` ekleyin. (`PORT` değişkenini Render kendisi verir.)
4. Health check path: `/healthz` (ilk denemede `/healtz` yazım hatası deploy'u beklemede bıraktı).

## Bilinen eksikler

- **İlk istek yavaş olabilir:** Render ücretsiz planı boştaki servisi uyutur; ilk istek ~30–60 sn sürebilir. İstemci 30 sn'de zaman aşımına uğrar ve "kaydedilmemiş olabilir, tekrar deneyin" der.
- **Zaman aşımından sonra mükerrer kayıt olabilir:** Sunucu yazmayı bitirip yanıt geç ulaşırsa, kullanıcının tekrar denemesi ikinci kayıt oluşturur. Çözüm: istemcinin ürettiği idempotency anahtarı (yapılmadı).
- **Rate limit bellek içi:** Tek sunucu örneği için geçerli, yeniden başlatmada sıfırlanır. Ayrıca `X-Forwarded-For` başlığı istemci tarafından taklit edilebilir. Gerçek üründe Redis gibi paylaşılan bir sayaç ve platformun güvenilir IP başlığı kullanılmalı.
- **Doğrulama kuralları iki dilde yazılı** (JS ve Dart). Değişiklikte ikisi birlikte güncellenmeli; sunucu asıl yetkidir.
- **E-posta doğrulaması biçimsel:** Adresin gerçekten var olduğu kontrol edilmez.
- **Yönetim paneli yok:** Kayıtlar `tool/list_leads.dart` veya Neon SQL editöründen görüntülenir.
- **Tarayıcı otomasyon testi yok:** Arayüz akışları elle (tarayıcıda) sınandı; Playwright gibi otomatik bir E2E testi eklenmedi.
- **KVKK/aydınlatma metni yok:** Kurgusal hizmet olduğu için eklenmedi; gerçek üründe zorunlu.

## Kaynaklar ve katkılar

- Hazır şablon kullanılmadı. Sayfa, stil ve kod bu proje için yazıldı.
- Kullanılan açık kaynak paketler: `shelf`, `shelf_router`, `shelf_static`, `postgres`, `test`, `http`, `lints` (pub.dev).
- `Dockerfile`, Dart resmi imajının belgelenmiş iki aşamalı derleme kalıbını izler.
- Kodun büyük kısmı Claude Code (AI) ile birlikte yazıldı; kararlar ve doğrulama adımları [AI_LOG.md](AI_LOG.md) içinde.
