// YALNIZCA YEREL ARAYÜZ GELİŞTİRME İÇİN. Kayıtlar bellekte tutulur ve sunucu
// kapanınca silinir. Canlı ortam bin/server.dart'ı (Postgres) kullanır.
//
//   dart run tool/dev_server.dart            → normal
//   dart run tool/dev_server.dart --fail-db  → her kayıt denemesi 500 döner
//   dart run tool/dev_server.dart --slow     → yanıtlar 3 sn gecikir
import 'dart:io';

import 'package:ustarota/ustarota.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

class _DevRepo implements LeadRepository {
  final bool fail;
  final Duration delay;
  int _id = 0;
  _DevRepo({required this.fail, required this.delay});

  @override
  Future<int> insert(LeadInput lead) async {
    await Future<void>.delayed(delay);
    if (fail) throw StateError('simüle edilmiş veritabanı hatası');
    stdout.writeln('[dev] bellek kaydı #${_id + 1}: ${lead.service}');
    return ++_id;
  }

  @override
  Future<void> close() async {}
}

Future<void> main(List<String> args) async {
  final handler = buildHandler(
    repository: _DevRepo(
      fail: args.contains('--fail-db'),
      delay: args.contains('--slow') ? const Duration(seconds: 3) : Duration.zero,
    ),
    rateLimiter: RateLimiter(maxRequests: 5, window: const Duration(minutes: 10)),
  );
  final server = await io.serve(logRequests().addHandler(handler), 'localhost', 8080);
  print('[dev] BELLEK İÇİ sunucu (kalıcı değil): http://localhost:${server.port}');
}
