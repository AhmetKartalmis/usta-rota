import 'dart:convert';

import 'package:ustarota/ustarota.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Kayıtları bellekte tutan sahte depo.
class MemoryRepo implements LeadRepository {
  final saved = <LeadInput>[];
  @override
  Future<int> insert(LeadInput lead) async {
    saved.add(lead);
    return saved.length;
  }

  @override
  Future<void> close() async {}
}

/// Veritabanı kesintisini taklit eder.
class FailingRepo implements LeadRepository {
  @override
  Future<int> insert(LeadInput lead) => throw StateError('db down');
  @override
  Future<void> close() async {}
}

const validBody = {
  'name': 'Deneme Kullanıcı',
  'email': 'Test@Ornek-Firma.test',
  'service': 'tesisat',
  'message': '12 yıllık tecrübe, Üsküdar çevresinde su tesisatı arıza onarımı.',
};

Handler handlerWith(LeadRepository repo, {int limit = 100}) => buildHandler(
      repository: repo,
      rateLimiter: RateLimiter(maxRequests: limit, window: const Duration(minutes: 10)),
      publicDir: null,
      log: (_) {},
    );

Future<Response> post(Handler h, Object body,
    {String contentType = 'application/json', String ip = '1.1.1.1'}) {
  return Future.sync(() => h(Request(
        'POST',
        Uri.parse('http://localhost/api/leads'),
        body: body is String ? body : jsonEncode(body),
        headers: {'content-type': contentType, 'x-forwarded-for': ip},
      )));
}

Future<Map<String, dynamic>> json(Response r) async =>
    jsonDecode(await r.readAsString()) as Map<String, dynamic>;

void main() {
  test('geçerli talep 201 döner ve depoya normalize edilmiş halde yazılır', () async {
    final repo = MemoryRepo();
    final res = await post(handlerWith(repo), validBody);

    expect(res.statusCode, 201);
    expect(await json(res), {'ok': true, 'id': 1});
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.email, 'test@ornek-firma.test');
  });

  test('veritabanı hatasında 500 döner, asla başarı dönmez', () async {
    final logs = <String>[];
    final h = buildHandler(
      repository: FailingRepo(),
      rateLimiter: RateLimiter(maxRequests: 100, window: const Duration(minutes: 1)),
      publicDir: null,
      log: logs.add,
    );
    final res = await post(h, validBody);
    final body = await json(res);

    expect(res.statusCode, 500);
    expect(body['ok'], false);
    expect(body.containsKey('id'), isFalse);
    // Log'a kişisel veri sızmamalı.
    expect(logs.single, isNot(contains('ornek-firma')));
  });

  test('geçersiz alanlarda 400 ve alan bazlı hatalar döner, kayıt yapılmaz', () async {
    final repo = MemoryRepo();
    final res = await post(handlerWith(repo),
        {'name': 'A', 'email': 'gecersiz', 'service': 'hack', 'message': 'kısa'});
    final body = await json(res);

    expect(res.statusCode, 400);
    expect((body['errors'] as Map).keys,
        containsAll(['name', 'email', 'service', 'message']));
    expect(repo.saved, isEmpty);
  });

  test('bozuk JSON ve bozuk UTF-8 400 döner', () async {
    final h = handlerWith(MemoryRepo());
    expect((await post(h, '{bozuk')).statusCode, 400);

    final res = await h(Request('POST', Uri.parse('http://localhost/api/leads'),
        body: [0xff, 0xfe, 0x7b], headers: {'content-type': 'application/json'}));
    expect(res.statusCode, 400);
  });

  test('JSON olmayan içerik türü 415 döner', () async {
    final res = await post(handlerWith(MemoryRepo()), 'name=x',
        contentType: 'application/x-www-form-urlencoded');
    expect(res.statusCode, 415);
  });

  test('16 KB üzerindeki gövde 413 döner', () async {
    final big = {...validBody, 'message': 'a' * (maxBodyBytes + 1)};
    final res = await post(handlerWith(MemoryRepo()), big);
    expect(res.statusCode, 413);
  });

  test('honeypot dolu ise kayıt yapılmaz ve başarı dönmez', () async {
    final repo = MemoryRepo();
    final res = await post(handlerWith(repo), {...validBody, 'website': 'http://spam'});
    expect(res.statusCode, 400);
    expect(repo.saved, isEmpty);
  });

  test('aynı IP sınırı aşınca 429 döner, farklı IP etkilenmez', () async {
    final repo = MemoryRepo();
    final h = handlerWith(repo, limit: 2);
    expect((await post(h, validBody, ip: '9.9.9.9')).statusCode, 201);
    expect((await post(h, validBody, ip: '9.9.9.9')).statusCode, 201);

    final blocked = await post(h, validBody, ip: '9.9.9.9');
    expect(blocked.statusCode, 429);
    expect(blocked.headers['retry-after'], isNotNull);
    expect((await post(h, validBody, ip: '8.8.8.8')).statusCode, 201);
    expect(repo.saved, hasLength(3));
  });

  test('yanıtlarda güvenlik başlıkları var', () async {
    final res = await post(handlerWith(MemoryRepo()), validBody);
    expect(res.headers['content-security-policy'], contains("default-src 'self'"));
    expect(res.headers['x-content-type-options'], 'nosniff');
  });

  test('bilinmeyen API yolu JSON 404 döner', () async {
    final h = handlerWith(MemoryRepo());
    final res = await h(Request('GET', Uri.parse('http://localhost/api/yok')));
    expect(res.statusCode, 404);
    expect(res.headers['content-type'], contains('application/json'));
  });
}
