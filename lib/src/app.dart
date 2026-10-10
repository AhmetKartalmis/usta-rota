import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpConnectionInfo;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'lead_repository.dart';
import 'rate_limiter.dart';
import 'validation.dart';

const maxBodyBytes = 16 * 1024;

/// Uygulamanın tüm HTTP davranışı. Sunucu (bin/server.dart) ve testler aynı
/// handler'ı kullanır; testler gerçek port açmadan doğrudan çağırır.
Handler buildHandler({
  required LeadRepository repository,
  required RateLimiter rateLimiter,
  String? publicDir = 'public',
  void Function(String message)? log,
}) {
  final logError = log ?? print;
  final router = Router()
    ..get('/healthz', (Request _) => Response.ok('ok'))
    ..post('/api/leads', (Request request) async {
      return _createLead(request, repository, rateLimiter, logError);
    })
    ..all('/api/<rest|.*>', (Request _) => _json(404, {
          'ok': false,
          'errors': {'form': 'Bulunamadı.'},
        }));

  var cascade = Cascade().add(router.call);
  if (publicDir != null) {
    cascade = cascade.add(
      createStaticHandler(publicDir, defaultDocument: 'index.html'),
    );
  }

  return const Pipeline()
      .addMiddleware(_securityHeaders())
      .addHandler(cascade.handler);
}

Future<Response> _createLead(
  Request request,
  LeadRepository repository,
  RateLimiter rateLimiter,
  void Function(String) logError,
) async {
  if (!rateLimiter.allow(_clientIp(request))) {
    return _json(
      429,
      {
        'ok': false,
        'errors': {
          'form': 'Kısa sürede çok fazla başvuru gönderildi. '
              'Lütfen birkaç dakika sonra tekrar deneyin.',
        },
      },
      headers: {'retry-after': '600'},
    );
  }

  if (request.mimeType != 'application/json') {
    return _json(415, {
      'ok': false,
      'errors': {'form': 'İstek JSON biçiminde olmalı.'},
    });
  }

  final Object? body;
  try {
    body = jsonDecode(await _readLimited(request, maxBodyBytes));
  } on _BodyTooLarge {
    return _json(413, {
      'ok': false,
      'errors': {'form': 'İstek çok büyük.'},
    });
  } on FormatException {
    // Hem bozuk UTF-8 hem bozuk JSON buraya düşer.
    return _json(400, {
      'ok': false,
      'errors': {'form': 'Geçersiz istek gövdesi.'},
    });
  }

  // Honeypot: insanlar bu gizli alanı görmez. Doluysa reddedilir; bota sahte
  // başarı dönülmez, çünkü başarı yanıtı yalnızca gerçek kayıt için verilir.
  if (body is Map && (body['website'] ?? '').toString().isNotEmpty) {
    return _json(400, {
      'ok': false,
      'errors': {'form': 'Başvuru gönderilemedi.'},
    });
  }

  final result = validateLead(body);
  if (!result.isValid) {
    return _json(400, {'ok': false, 'errors': result.errors});
  }

  try {
    final id = await repository.insert(result.lead!);
    return _json(201, {'ok': true, 'id': id});
  } catch (e) {
    // Kişisel veri loglanmaz; yalnızca hata türü ve mesajı.
    logError('lead insert failed: ${e.runtimeType}: $e');
    return _json(500, {
      'ok': false,
      'errors': {
        'form': 'Başvurunuz şu an kaydedilemedi. Lütfen biraz sonra tekrar '
            'deneyin; bilgileriniz formda duruyor.',
      },
    });
  }
}

/// Render gibi platformlarda istek bir proxy üzerinden gelir; istemci IP'si
/// X-Forwarded-For başlığının ilk değeridir. Bu başlık istemci tarafından
/// taklit edilebilir (README > Bilinen eksikler).
String _clientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded.split(',').first.trim();
  }
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
}

class _BodyTooLarge implements Exception {}

Future<String> _readLimited(Request request, int limit) async {
  final declared = request.contentLength;
  if (declared != null && declared > limit) throw _BodyTooLarge();

  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
    if (bytes.length > limit) throw _BodyTooLarge();
  }
  return utf8.decode(bytes, allowMalformed: false);
}

Response _json(int status, Object body, {Map<String, String>? headers}) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      ...?headers,
    },
  );
}

Middleware _securityHeaders() {
  const headers = {
    // Satır içi script/stil yok; her şey kendi kaynağımızdan.
    'content-security-policy': "default-src 'self'; img-src 'self' data:; "
        "style-src 'self'; script-src 'self'; connect-src 'self'; "
        "frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'strict-origin-when-cross-origin',
    'permissions-policy': 'camera=(), microphone=(), geolocation=()',
  };
  return (inner) => (request) async {
        final response = await inner(request);
        return response.change(headers: headers);
      };
}
