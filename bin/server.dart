import 'dart:io';

import 'package:ustarota/ustarota.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final env = {..._readDotEnv(), ...Platform.environment};

  final databaseUrl = env['DATABASE_URL'];
  if (databaseUrl == null || databaseUrl.isEmpty) {
    // Veritabanı olmadan çalışmak, kaydı olmayan "başarılı" yanıtlara kapı
    // açar; bu yüzden sunucu hiç açılmaz.
    stderr.writeln('DATABASE_URL tanımlı değil. .env.example dosyasına bakın.');
    exit(1);
  }

  final repository = await PostgresLeadRepository.connect(databaseUrl);
  final handler = buildHandler(
    repository: repository,
    rateLimiter: RateLimiter(maxRequests: 5, window: const Duration(minutes: 10)),
  );

  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(
    logRequests().addHandler(handler),
    InternetAddress.anyIPv4,
    port,
  );
  print('Sunucu hazır: http://localhost:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    await repository.close();
    exit(0);
  });
}

/// Yalnızca yerel geliştirme için basit .env okuyucu (KEY=VALUE satırları).
/// Canlıda değişkenler platformdan gelir ve .env dosyası repoda yoktur.
Map<String, String> _readDotEnv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final i = trimmed.indexOf('=');
    if (i <= 0) continue;
    var value = trimmed.substring(i + 1).trim();
    if (value.length >= 2 &&
        (value.startsWith('"') && value.endsWith('"') ||
            value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    values[trimmed.substring(0, i).trim()] = value;
  }
  return values;
}
