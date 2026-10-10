// Veritabanındaki son başvuruları listeler (kalıcılığı elle doğrulamak için).
//   dart run tool/list_leads.dart        → son 10 kayıt
//   dart run tool/list_leads.dart 50     → son 50 kayıt
// DATABASE_URL ortam değişkeninden veya .env dosyasından okunur.
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:ustarota/ustarota.dart';

Future<void> main(List<String> args) async {
  final url = Platform.environment['DATABASE_URL'] ??
      File('.env')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('DATABASE_URL='), orElse: () => '')
          .replaceFirst('DATABASE_URL=', '');
  if (url.isEmpty) {
    stderr.writeln('DATABASE_URL tanımlı değil.');
    exit(1);
  }

  final limit = int.tryParse(args.firstOrNull ?? '') ?? 10;
  final pool = Pool.withUrl(normalizeDatabaseUrl(url));
  final rows = await pool.execute(
    Sql.named('SELECT id, created_at, name, email, service, message '
        'FROM leads ORDER BY id DESC LIMIT @limit'),
    parameters: {'limit': limit},
  );
  for (final r in rows) {
    final m = r.toColumnMap();
    print('#${m['id']}  ${(m['created_at'] as DateTime).toUtc().toIso8601String()}  '
        '${m['service']}  ${m['name']} <${m['email']}>\n    ${m['message']}');
  }
  print('${rows.length} kayıt gösterildi.');
  await pool.close();
}
