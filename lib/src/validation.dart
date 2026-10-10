/// Talep formunun sunucu tarafı doğrulaması.
///
/// İstemcideki kurallar (public/app.js) kullanıcı deneyimi içindir; asıl yetki
/// buradadır. Kurallar değişirse iki dosya birlikte güncellenmeli.
library;

/// Formda seçilebilecek hizmetler. Anahtar veritabanına yazılır, değer
/// kullanıcıya gösterilir. public/index.html içindeki <option> listesiyle aynı.
const services = <String, String>{
  'tesisat': 'Su tesisatı',
  'elektrik': 'Elektrik',
  'klima': 'Kombi ve klima servisi',
  'beyazesya': 'Beyaz eşya tamiri',
  'boya': 'Boya ve badana',
  'temizlik': 'Ev ve ofis temizliği',
  'nakliyat': 'Nakliyat',
  'montaj': 'Mobilya montajı ve marangozluk',
  'cilingir': 'Çilingir',
  'bahce': 'Bahçe bakımı',
};

const nameMin = 2, nameMax = 100;
const emailMax = 254;
const messageMin = 20, messageMax = 200;

// Bilinçli olarak sade: RFC 5322'nin tamamı yerine "x@y.z" biçimi ve boşluk yok.
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

// Satır sonu ve sekme dışındaki kontrol karakterleri (ör. \u0000) reddedilir.
final _controlChars = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');

class LeadInput {
  final String name;
  final String email;
  final String service;
  final String message;

  const LeadInput({
    required this.name,
    required this.email,
    required this.service,
    required this.message,
  });
}

class ValidationResult {
  final LeadInput? lead;
  final Map<String, String> errors;

  const ValidationResult._(this.lead, this.errors);

  bool get isValid => lead != null;
}

/// JSON gövdesini doğrular ve normalize eder (trim, e-posta küçük harf).
/// Alan bazlı Türkçe hata mesajları döner; istemci bunları ilgili alanın
/// altında gösterir.
ValidationResult validateLead(Object? body) {
  if (body is! Map) {
    return const ValidationResult._(null, {'form': 'Geçersiz istek gövdesi.'});
  }

  final errors = <String, String>{};

  String? text(String key) {
    final v = body[key];
    if (v == null) return '';
    if (v is! String) {
      errors[key] = 'Bu alan metin olmalı.';
      return null;
    }
    return v.trim();
  }

  final name = text('name');
  final email = text('email')?.toLowerCase();
  final service = text('service');
  final message = text('message');

  if (name != null && !errors.containsKey('name')) {
    if (name.isEmpty) {
      errors['name'] = 'Adınızı yazın.';
    } else if (name.length < nameMin || name.length > nameMax) {
      errors['name'] = 'Ad $nameMin–$nameMax karakter olmalı.';
    } else if (_controlChars.hasMatch(name) || name.contains('\n')) {
      errors['name'] = 'Ad geçersiz karakter içeriyor.';
    }
  }

  if (email != null && !errors.containsKey('email')) {
    if (email.isEmpty) {
      errors['email'] = 'E-posta adresinizi yazın.';
    } else if (email.length > emailMax || !_emailPattern.hasMatch(email)) {
      errors['email'] = 'Geçerli bir e-posta adresi yazın (ör. ad@firma.com).';
    }
  }

  if (service != null && !errors.containsKey('service')) {
    if (service.isEmpty) {
      errors['service'] = 'Bir hizmet seçin.';
    } else if (!services.containsKey(service)) {
      errors['service'] = 'Listeden geçerli bir hizmet seçin.';
    }
  }

  if (message != null && !errors.containsKey('message')) {
    if (message.isEmpty) {
      errors['message'] = 'İşinizi kısaca anlatın.';
    } else if (message.length < messageMin) {
      errors['message'] = 'Açıklama en az $messageMin karakter olmalı.';
    } else if (message.length > messageMax) {
      errors['message'] = 'Açıklama en fazla $messageMax karakter olabilir.';
    } else if (_controlChars.hasMatch(message)) {
      errors['message'] = 'Açıklama geçersiz karakter içeriyor.';
    }
  }

  if (errors.isNotEmpty) return ValidationResult._(null, errors);

  return ValidationResult._(
    LeadInput(name: name!, email: email!, service: service!, message: message!),
    const {},
  );
}
