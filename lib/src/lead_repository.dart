import 'package:postgres/postgres.dart';

import 'validation.dart';

/// Talepleri kalıcı olarak saklayan katman. API bu arayüze bağlıdır; testlerde
/// bellek içi veya bilerek hata veren sürümler takılır.
abstract interface class LeadRepository {
  /// Kaydı yazar ve veritabanının verdiği kimliği döner. Yazma başarısızsa
  /// istisna fırlatır — API bu durumda asla başarı yanıtı vermez.
  Future<int> insert(LeadInput lead);

  Future<void> close();
}

/// Tablo şeması. CHECK kısıtları uygulama doğrulamasının ikinci savunma hattı:
/// kod hatası olsa bile geçersiz veri tabloya giremez. Sınırlar ve hizmet
/// listesi validation.dart'taki sabitlerden üretilir (kod içi sabitler,
/// kullanıcı verisi değil), böylece iki yer birbirinden kopamaz.
final schemaSql = '''
CREATE TABLE IF NOT EXISTS leads (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  name        TEXT NOT NULL CHECK (char_length(name) BETWEEN $nameMin AND $nameMax),
  email       TEXT NOT NULL CHECK (char_length(email) BETWEEN 3 AND $emailMax),
  service     TEXT NOT NULL CHECK (service IN (${services.keys.map((k) => "'$k'").join(',')})),
  message     TEXT NOT NULL CHECK (char_length(message) BETWEEN $messageMin AND $messageMax)
)''';

class PostgresLeadRepository implements LeadRepository {
  final Pool _pool;

  PostgresLeadRepository._(this._pool);

  /// [url] örn. postgresql://user:pass@host/db?sslmode=require
  static Future<PostgresLeadRepository> connect(String url) async {
    final pool = Pool.withUrl(normalizeDatabaseUrl(url));
    final repo = PostgresLeadRepository._(pool);
    await pool.execute(schemaSql);
    return repo;
  }

  @override
  Future<int> insert(LeadInput lead) async {
    // Parametreli sorgu: kullanıcı verisi SQL metnine asla birleştirilmez.
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO leads (name, email, service, message) '
        'VALUES (@name, @email, @service, @message) RETURNING id',
      ),
      parameters: {
        'name': lead.name,
        'email': lead.email,
        'service': lead.service,
        'message': lead.message,
      },
    );
    return result.first.first! as int;
  }

  @override
  Future<void> close() => _pool.close();
}

/// Neon'un verdiği bağlantı adresinde `channel_binding=require` bulunur;
/// postgres 3.5.x bu parametreyi tanımadığı için ArgumentError fırlatır.
/// SSL zorunluluğu `sslmode` ile korunur, yalnızca bu parametre çıkarılır.
String normalizeDatabaseUrl(String url) {
  final uri = Uri.parse(url);
  if (!uri.queryParameters.containsKey('channel_binding')) return url;
  final params = Map.of(uri.queryParameters)..remove('channel_binding');
  return uri.replace(queryParameters: params.isEmpty ? null : params).toString();
}
