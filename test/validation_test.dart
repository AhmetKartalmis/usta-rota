import 'package:ustarota/ustarota.dart';
import 'package:test/test.dart';

Map<String, Object?> body({
  Object? name = 'Ayşe Deneme',
  Object? email = 'ayse@ornek.test',
  Object? service = 'tesisat',
  Object? message = 'Sipariş durumlarını otomatik güncellemek istiyoruz.',
}) =>
    {'name': name, 'email': email, 'service': service, 'message': message};

void main() {
  test('geçerli girdi kabul edilir ve normalize edilir', () {
    final r = validateLead(body(name: '  Ayşe  ', email: ' AYSE@Ornek.TEST '));
    expect(r.isValid, isTrue);
    expect(r.lead!.name, 'Ayşe');
    expect(r.lead!.email, 'ayse@ornek.test');
  });

  test('gövde nesne değilse reddedilir', () {
    expect(validateLead(['dizi']).errors, contains('form'));
    expect(validateLead(null).errors, contains('form'));
  });

  test('eksik alanlar ayrı ayrı raporlanır', () {
    final r = validateLead(<String, Object?>{});
    expect(r.errors.keys, ['name', 'email', 'service', 'message']);
  });

  test('metin olmayan değer reddedilir', () {
    expect(validateLead(body(name: 42)).errors['name'], 'Bu alan metin olmalı.');
  });

  group('sınırlar', () {
    test('ad 2–100 karakter', () {
      expect(validateLead(body(name: 'A')).isValid, isFalse);
      expect(validateLead(body(name: 'AB')).isValid, isTrue);
      expect(validateLead(body(name: 'A' * 100)).isValid, isTrue);
      expect(validateLead(body(name: 'A' * 101)).isValid, isFalse);
    });

    test('açıklama 20–200 karakter', () {
      expect(validateLead(body(message: 'a' * 19)).isValid, isFalse);
      expect(validateLead(body(message: 'a' * 20)).isValid, isTrue);
      expect(validateLead(body(message: 'a' * 200)).isValid, isTrue);
      expect(validateLead(body(message: 'a' * 201)).isValid, isFalse);
    });

    test('boşluktan ibaret değer boş sayılır', () {
      expect(validateLead(body(message: ' ' * 30)).errors['message'],
          'İşinizi kısaca anlatın.');
    });
  });

  test('e-posta biçimi', () {
    for (final bad in ['abc', 'a@b', 'a @b.com', '@b.com', 'a@b.c']) {
      expect(validateLead(body(email: bad)).isValid, isFalse, reason: bad);
    }
    expect(validateLead(body(email: '${'a' * 250}@b.co')).isValid, isFalse);
  });

  test('yalnızca listedeki hizmetler kabul edilir', () {
    expect(validateLead(body(service: 'TESISAT')).isValid, isFalse);
    expect(validateLead(body(service: "x'; DROP TABLE leads;--")).isValid, isFalse);
    for (final key in services.keys) {
      expect(validateLead(body(service: key)).isValid, isTrue);
    }
  });

  test('kontrol karakterleri reddedilir, açıklamada satır sonu serbest', () {
    expect(validateLead(body(name: 'Ali\u0000Veli')).isValid, isFalse);
    expect(validateLead(body(name: 'Ali\nVeli')).isValid, isFalse);
    expect(validateLead(body(message: 'Birinci satır\nikinci satır')).isValid, isTrue);
  });

  test('HTML içeren metin reddedilmez, olduğu gibi saklanır (çıktıda kaçışlanır)', () {
    final r = validateLead(body(message: '<script>alert(1)</script> deneme'));
    expect(r.isValid, isTrue);
    expect(r.lead!.message, contains('<script>'));
  });

  test('rate limiter pencere dolunca açılır', () {
    var now = DateTime(2026);
    final rl = RateLimiter(maxRequests: 1, window: const Duration(minutes: 10), now: () => now);
    expect(rl.allow('ip'), isTrue);
    expect(rl.allow('ip'), isFalse);
    now = now.add(const Duration(minutes: 11));
    expect(rl.allow('ip'), isTrue);
  });
}
