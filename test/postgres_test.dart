import 'dart:io';

import 'package:ustarota/ustarota.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeDatabaseUrl', () {
    test('Neon adresindeki channel_binding çıkarılır, sslmode korunur', () {
      final out = normalizeDatabaseUrl(
          'postgresql://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require');
      expect(out, contains('sslmode=require'));
      expect(out, isNot(contains('channel_binding')));
      // Sonuç paket tarafından kabul edilmeli (önceden ArgumentError fırlatıyordu).
      expect(() => Pool.withUrl(out), returnsNormally);
    });

    test('özel karakterli parola bozulmaz', () {
      const url = 'postgresql://u:p%40ss%2Fw@host/db?sslmode=require&channel_binding=require';
      expect(Uri.parse(normalizeDatabaseUrl(url)).userInfo, 'u:p%40ss%2Fw');
    });

    test('channel_binding yoksa adres aynen döner', () {
      const url = 'postgresql://u:p@host/db?sslmode=require';
      expect(normalizeDatabaseUrl(url), url);
    });
  });

  // Gerçek veritabanına karşı kalıcılık testi. Çalıştırmak için:
  //   $env:TEST_DATABASE_URL="postgresql://..."; dart test test/postgres_test.dart
  final url = Platform.environment['TEST_DATABASE_URL'];
  test('kayıt veritabanına yazılır ve ayrı bir bağlantıdan okunur', () async {
    final repo = await PostgresLeadRepository.connect(url!);
    final marker = 'kalicilik-testi-${DateTime.now().microsecondsSinceEpoch}';
    final id = await repo.insert(LeadInput(
      name: 'Test Kaydı',
      email: 'test@ornek.test',
      service: 'tesisat',
      message: marker,
    ));
    await repo.close();

    // Yeni bir havuz: önbellek ya da aynı oturum değil, gerçekten diskten.
    final pool = Pool.withUrl(normalizeDatabaseUrl(url));
    final rows = await pool.execute(
      Sql.named('SELECT message FROM leads WHERE id = @id'),
      parameters: {'id': id},
    );
    await pool.close();
    expect(rows.single.single, marker);
  }, skip: url == null ? 'TEST_DATABASE_URL tanımlı değil' : false);
}
