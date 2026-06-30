import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class LocalStreamingProxy {
  static final LocalStreamingProxy instance = LocalStreamingProxy._internal();

  HttpServer? _server;
  int _port = 0;
  String _lastBaseUrl = '';
  String _lastReferer = '';

  final Map<String, InternetAddress> _ipv4Cache = {};
  // Cache redirect targets: original_url_prefix → final_host so segments skip redirect hop
  final Map<String, String> _redirectCache = {};

  Future<void> _preResolveIPv4(String host) async {
    if (_ipv4Cache.containsKey(host)) return;
    try {
      final addresses = await InternetAddress.lookup(host, type: InternetAddressType.IPv4);
      if (addresses.isNotEmpty) {
        _ipv4Cache[host] = addresses.first;
      }
    } catch (_) {}
  }

  // Standard HttpClient with bad certificate bypass (critical for proxying HTTPS streams)
  late final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..maxConnectionsPerHost = 100
    ..connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) {
      final host = proxyHost ?? uri.host;
      final port = proxyPort ?? uri.port;
      final cached = _ipv4Cache[host];
      if (uri.scheme == 'https') {
        if (cached != null) {
          return SecureSocket.startConnect(cached, port, onBadCertificate: (cert) => true);
        }
        return SecureSocket.startConnect(host, port, onBadCertificate: (cert) => true);
      } else {
        if (cached != null) {
          return Socket.startConnect(cached, port);
        }
        return Socket.startConnect(host, port);
      }
    }
    ..badCertificateCallback = (cert, host, port) => true;

  LocalStreamingProxy._internal();

  static const _skipResponseHeaders = {
    'transfer-encoding',
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailers',
    'upgrade',
    'content-encoding',
  };

  int get port => _port;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('[LocalStreamingProxy] Started internal proxy server on port $_port');

      _server!.listen((HttpRequest request) async {
        try {
          if (request.uri.path == '/play' || request.uri.path == '/play.ts') {
            await _handleProxyRequest(request);
          } else if (_lastBaseUrl.isNotEmpty) {
            await _handleRelativeRequest(request);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (e) {
          debugPrint('[LocalStreamingProxy] Error handling request: $e');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('[LocalStreamingProxy] Failed to start internal proxy: $e');
    }
  }

  Future<void> _handleProxyRequest(HttpRequest request) async {
    final queryStr = request.uri.query;
    final urlMatch = RegExp(r'(?:^|&)url=([^&]+)').firstMatch(queryStr);

    if (urlMatch == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final targetUrl = Uri.decodeComponent(urlMatch.group(1)!);
    final bool previousWasKorso = _lastBaseUrl.contains('korso420dim.com');
    _lastBaseUrl = targetUrl;

    final refererMatch = RegExp(r'(?:^|&)referer=([^&]+)').firstMatch(queryStr);
    final String? reqReferer = refererMatch != null ? Uri.decodeComponent(refererMatch.group(1)!) : null;

    final bool isTikTok = targetUrl.contains('tiktokcdn.com');
    final bool isTikTokSegment = isTikTok && targetUrl.contains('.image');
    final bool isAoneroom = targetUrl.contains('aoneroom.com') || targetUrl.contains('hakunaymatata.com');
    final bool isLookMovie = targetUrl.contains('premilkyway.com') || targetUrl.contains('uqloads.com') || targetUrl.contains('lookmovie') || targetUrl.contains('korso420dim.com');
    // On Android and iOS, direct connection is preferred to ensure the client IP matches the signed IP in the URL.
    final bool useVercel = isLookMovie && 
                           !targetUrl.contains('ver-orcin-alpha.vercel.app') && 
                           !(Platform.isAndroid || Platform.isIOS);

    if (request.uri.path == '/play') {
      _lastReferer = '';
    }
    Uri targetUri;
    if (isTikTok) {
      targetUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(targetUrl)}');
      debugPrint('[LocalStreamingProxy] Routing TikTok CDN to Singapore Vercel: $targetUri');
    } else if (useVercel) {
      _lastReferer = reqReferer ?? 'https://lookmovie2.skin/';
      targetUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(targetUrl)}&referer=${Uri.encodeComponent(_lastReferer)}');
      debugPrint('[LocalStreamingProxy] Routing Protected CDN through Singapore Vercel: $targetUri');
    } else {
      var parsedUri = Uri.parse(targetUrl);
      try {
        if ((previousWasKorso || targetUrl.contains('korso420dim.com')) && 
            !parsedUri.host.contains('korso420dim.com') && 
            (parsedUri.host.contains('.site') || parsedUri.host.contains('absole-catenaliggette'))) {
          final prefix = parsedUri.host.split('.').first;
          final realTargetHost = '$prefix.korso420dim.com';
          parsedUri = parsedUri.replace(host: realTargetHost);
          _lastBaseUrl = parsedUri.toString();
          debugPrint('[LocalStreamingProxy] Substituted fake host in play request -> $realTargetHost');
        }
      } catch (_) {}
      targetUri = parsedUri;
      // debugPrint('[LocalStreamingProxy] Proxying to: ${targetUri.host}${targetUri.path}');
    }

    try {
      await _preResolveIPv4(targetUri.host);
      final clientReq = await _client.getUrl(targetUri);
      clientReq.contentLength = -1;
      clientReq.headers.chunkedTransferEncoding = false;

      if (isTikTok) {
        clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      } else if (useVercel) {
        // Vercel proxy handles headers; local proxy sends clean request to Vercel
        clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      } else if (isAoneroom) {
        _lastReferer = 'https://www.movieboxpro.app/';
        clientReq.headers.set('Referer', _lastReferer);
        clientReq.headers.set('Origin', 'https://www.movieboxpro.app');
        clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36');
      } else {
        if (reqReferer != null && !targetUrl.contains('archive.org')) {
          _lastReferer = reqReferer;
          clientReq.headers.set('Referer', _lastReferer);
          try {
            final refUri = Uri.parse(reqReferer);
            clientReq.headers.set('Origin', '${refUri.scheme}://${refUri.host}');
          } catch (_) {}
        }
        // No explicit CDN type — use neutral desktop UA (no special Referer/Origin)
        clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      }

      clientReq.headers.set('Accept', '*/*');
      clientReq.headers.set('Accept-Language', 'en-US,en;q=0.9');
      clientReq.headers.set('Accept-Encoding', 'identity');

      final cookieHeader = request.headers.value('cookie');
      if (cookieHeader != null) {
        clientReq.headers.set('Cookie', cookieHeader);
      }

      final authMatch = RegExp(r'(?:^|&)auth=([^&]+)').firstMatch(queryStr);
      if (authMatch != null && isAoneroom) {
        clientReq.headers.set('Authorization', Uri.decodeComponent(authMatch.group(1)!));
      }

      final rangeHeader = request.headers.value('range');
      bool needStrip = false;
      if (isTikTokSegment) {
        if (rangeHeader != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)?').firstMatch(rangeHeader);
          if (match != null) {
            final start = int.parse(match.group(1)!) + 70;
            final endGroup = match.group(2);
            final end = endGroup != null ? int.parse(endGroup) + 70 : null;
            clientReq.headers.set('Range', 'bytes=$start-${end ?? ''}');
          } else {
            clientReq.headers.set('Range', rangeHeader);
          }
        } else {
          needStrip = true;
        }
      } else if (rangeHeader != null) {
        clientReq.headers.set('Range', rangeHeader);
      }

      // Forward incoming client request headers directly to the target request
      // (e.g., Origin, Referer, User-Agent) to match exactly what player_screen configured
      request.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower != 'host' && 
            lower != 'content-length' && 
            lower != 'connection' && 
            lower != 'accept-encoding') {
          clientReq.headers.removeAll(name);
          for (final val in values) {
            clientReq.headers.add(name, val);
          }
        }
      });

      // Skip verbose headers console logging in production to prevent blocking
      // clientReq.headers.forEach((name, values) => debugPrint('  $name: ${values.join(", ")}'));

      clientReq.followRedirects = false;
      var clientResp = await clientReq.close();

      int redirectCount = 0;
      while (clientResp.statusCode >= 300 && clientResp.statusCode < 400 && redirectCount < 5) {
        final loc = clientResp.headers.value('location');
        if (loc == null || loc.isEmpty) break;
        
        await clientResp.drain();
        final nextUri = targetUri.resolve(loc);
        debugPrint('[LocalStreamingProxy] Following manual redirect to: $nextUri');
        
        await _preResolveIPv4(nextUri.host);
        final nextReq = await _client.getUrl(nextUri);
        nextReq.followRedirects = false;
        nextReq.contentLength = -1;
        nextReq.headers.chunkedTransferEncoding = false;
        
        clientReq.headers.forEach((name, values) {
          final lowerName = name.toLowerCase();
          if (lowerName != 'host' && lowerName != 'content-length') {
            bool isFirst = true;
            for (final val in values) {
              if (isFirst) {
                nextReq.headers.set(name, val);
                isFirst = false;
              } else {
                nextReq.headers.add(name, val);
              }
            }
          }
        });
        
        // Skip manual redirect headers logging
        // nextReq.headers.forEach((name, values) => debugPrint('  $name: ${values.join(", ")}'));
        
        targetUri = nextUri;
        clientResp = await nextReq.close();
        redirectCount++;
        
        // Cache redirect result for .ts segments to skip future redirect round-trips
        if (redirectCount == 1 && targetUri.path.endsWith('.ts')) {
          final cacheKey = Uri.parse(request.uri.queryParameters['url'] ?? '').host;
          _redirectCache[cacheKey] = targetUri.host;
        }
      }

      if (clientResp.statusCode >= 400) {
        final body = await clientResp.transform(utf8.decoder).join();
        debugPrint('[LocalStreamingProxy] CDN Error body: $body');
        request.response.statusCode = clientResp.statusCode;
        request.response.headers.contentType = ContentType.text;
        request.response.add(utf8.encode(body));
        await request.response.close();
        return;
      }

      request.response.statusCode = clientResp.statusCode;

      clientResp.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (!_skipResponseHeaders.contains(lower) && lower != 'content-type' && lower != 'content-range' && lower != 'content-length') {
          for (var value in values) {
            try {
              request.response.headers.add(name, value);
            } catch (_) {}
          }
        }
      });

      if (isTikTokSegment) {
        final contentRange = clientResp.headers.value('content-range');
        if (contentRange != null) {
          final rangeMatch = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
          if (rangeMatch != null) {
            final start = (int.parse(rangeMatch.group(1)!) - 70).clamp(0, 999999999999);
            final end = (int.parse(rangeMatch.group(2)!) - 70).clamp(0, 999999999999);
            final total = (int.parse(rangeMatch.group(3)!) - 70).clamp(0, 999999999999);
            request.response.headers.set('Content-Range', 'bytes $start-$end/$total');
          }
        }
        if (needStrip) {
          final lenStr = clientResp.headers.value('content-length');
          if (lenStr != null) {
            final len = int.parse(lenStr);
            request.response.headers.set('Content-Length', (len - 70).clamp(0, 999999999999).toString());
          }
        } else {
          final lenStr = clientResp.headers.value('content-length');
          if (lenStr != null) {
            request.response.headers.set('Content-Length', lenStr);
          }
        }
        request.response.headers.set('Content-Type', 'video/mp2t');
      } else {
        final cType = clientResp.headers.value('content-type') ?? 'video/mp4';
        request.response.headers.set('Content-Type', cType);
        final lenStr = clientResp.headers.value('content-length');
        if (lenStr != null) request.response.headers.set('Content-Length', lenStr);
        final contentRange = clientResp.headers.value('content-range');
        if (contentRange != null) request.response.headers.set('Content-Range', contentRange);
      }

      final cType = clientResp.headers.value('content-type') ?? 'video/mp4';
      if (targetUrl.toLowerCase().contains('.m3u8') || cType.toLowerCase().contains('mpegurl')) {
        final body = await clientResp.transform(utf8.decoder).join();
        final rewrittenBody = body.replaceAllMapped(RegExp(r'https://[^\s\r\n]+'), (match) {
          final originalUrl = match.group(0)!;
          final refParam = _lastReferer.isNotEmpty ? '&referer=${Uri.encodeComponent(_lastReferer)}' : '';
          return 'http://127.0.0.1:$_port/play.ts?url=${Uri.encodeComponent(originalUrl)}$refParam';
        });
        request.response.headers.set('Content-Type', 'application/vnd.apple.mpegurl');
        request.response.headers.contentLength = utf8.encode(rewrittenBody).length;
        request.response.add(utf8.encode(rewrittenBody));
        await request.response.close();
        debugPrint('[LocalStreamingProxy] Finished streaming rewritten m3u8');
      } else if (isTikTokSegment && needStrip) {
        int bytesRead = 0;
        bool stripped = false;
        await for (var chunk in clientResp) {
          if (!stripped) {
            if (bytesRead + chunk.length > 70) {
              final sliceOffset = 70 - bytesRead;
              request.response.add(chunk.sublist(sliceOffset));
              stripped = true;
            }
            bytesRead += chunk.length;
          } else {
            request.response.add(chunk);
          }
        }
        await request.response.close();
        debugPrint('[LocalStreamingProxy] Finished streaming stripped segment');
      } else {
        bool clientGone = false;
        request.response.done.then((_) {
          clientGone = true;
        }).catchError((_) {
          clientGone = true;
        });
        try {
          await for (final chunk in clientResp) {
            if (clientGone) {
              return;
            }
            request.response.add(chunk);
            await request.response.flush();
          }
        } catch (_) {
        } finally {
          if (!clientGone) {
            try {
              await request.response.close();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalStreamingProxy] Proxy request error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleRelativeRequest(HttpRequest request) async {
    if (_lastBaseUrl.isEmpty) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      var baseUri = Uri.parse(_lastBaseUrl);
      if (!baseUri.host.contains('korso420dim.com') && 
          (baseUri.host.contains('.site') || baseUri.host.contains('absole-catenaliggette'))) {
        final prefix = baseUri.host.split('.').first;
        baseUri = baseUri.replace(host: '$prefix.korso420dim.com');
      }
      
      final basePathSegments = List<String>.from(baseUri.pathSegments);
      if (basePathSegments.isNotEmpty) {
        basePathSegments.removeLast();
      }
      
      final relativePathSegments = request.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      basePathSegments.addAll(relativePathSegments);
      
      final targetUri = baseUri.replace(
        pathSegments: basePathSegments,
        queryParameters: request.uri.queryParameters.isEmpty ? null : request.uri.queryParameters,
      );

      final targetUrl = targetUri.toString();
      final bool isTikTok = targetUrl.contains('tiktokcdn.com');
      final bool isTikTokSegment = isTikTok && targetUrl.contains('.image');
      final bool isLookMovie = targetUrl.contains('premilkyway.com') || targetUrl.contains('uqloads.com') || targetUrl.contains('lookmovie') || targetUrl.contains('korso420dim.com');

      // On Android and iOS, direct connection is preferred to ensure the client IP matches the signed IP in the URL.
      final bool useVercel = isLookMovie && 
                             !targetUrl.contains('ver-orcin-alpha.vercel.app') && 
                             !(Platform.isAndroid || Platform.isIOS);

      Uri finalUri;
      if (isTikTok) {
        finalUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(targetUrl)}');
        debugPrint('[LocalStreamingProxy] Routing TikTok CDN relative to Singapore Vercel: $finalUri');
      } else if (useVercel) {
        final ref = _lastReferer.isNotEmpty ? _lastReferer : 'https://lookmovie2.skin/';
        finalUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(targetUrl)}&referer=${Uri.encodeComponent(ref)}');
        debugPrint('[LocalStreamingProxy] Routing Protected CDN relative through Singapore Vercel: $finalUri');
      } else {
        finalUri = targetUri;
        // debugPrint('[LocalStreamingProxy] Relative proxying to: $targetUrl');
      }

      await _preResolveIPv4(finalUri.host);
      final clientReq = await _client.getUrl(finalUri);
      clientReq.contentLength = -1;
      clientReq.headers.chunkedTransferEncoding = false;
      
      if (isTikTok) {
        clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      } else if (useVercel) {
        // Vercel handles headers; local proxy sends clean request to Vercel
        clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      } else if (isLookMovie) {
        clientReq.headers.set('Referer', 'https://lookmovie2.skin/');
        clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      } else {
        final bool isBaseAoneroom = _lastBaseUrl.contains('hakunaymatata.com') || _lastBaseUrl.contains('aoneroom.com');
        if (isBaseAoneroom) {
          clientReq.headers.set('Referer', 'https://www.movieboxpro.app/');
          clientReq.headers.set('Origin', 'https://www.movieboxpro.app');
          clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36');
        } else {
          // If a custom referer was captured in the main request, send it to HLS segments too!
          if (_lastReferer.isNotEmpty) {
            clientReq.headers.set('Referer', _lastReferer);
            try {
              final refUri = Uri.parse(_lastReferer);
              clientReq.headers.set('Origin', '${refUri.scheme}://${refUri.host}');
            } catch (_) {}
          }
          // Generic stream (e.g. moviesapi, allmovies CDNs) — use neutral desktop UA only
          clientReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
        }
      }
      clientReq.headers.set('Accept', '*/*');
      clientReq.headers.set('Accept-Encoding', 'identity');

      final cookieHeader = request.headers.value('cookie');
      if (cookieHeader != null) {
        clientReq.headers.set('Cookie', cookieHeader);
      }

      final rangeHeader = request.headers.value('range');
      bool needStrip = false;
      if (isTikTokSegment) {
        if (rangeHeader != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)?').firstMatch(rangeHeader);
          if (match != null) {
            final start = int.parse(match.group(1)!) + 70;
            final endGroup = match.group(2);
            final end = endGroup != null ? int.parse(endGroup) + 70 : null;
            clientReq.headers.set('Range', 'bytes=$start-${end ?? ''}');
          } else {
            clientReq.headers.set('Range', rangeHeader);
          }
        } else {
          needStrip = true;
        }
      } else if (rangeHeader != null) {
        clientReq.headers.set('Range', rangeHeader);
      }

      // Forward incoming client request headers directly to the target request
      // (e.g., Origin, Referer, User-Agent) to match exactly what player_screen configured
      request.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower != 'host' && 
            lower != 'content-length' && 
            lower != 'connection' && 
            lower != 'accept-encoding') {
          clientReq.headers.removeAll(name);
          for (final val in values) {
            clientReq.headers.add(name, val);
          }
        }
      });

      clientReq.followRedirects = false;
      var clientResp = await clientReq.close();
      debugPrint('[LocalStreamingProxy] Relative Response Status: ${clientResp.statusCode}');

      int redirectCount = 0;
      Uri relativeTargetUri = finalUri;
      while (clientResp.statusCode >= 300 && clientResp.statusCode < 400 && redirectCount < 5) {
        final loc = clientResp.headers.value('location');
        if (loc == null || loc.isEmpty) break;
        
        await clientResp.drain();
        final nextUri = relativeTargetUri.resolve(loc);
        debugPrint('[LocalStreamingProxy] Following manual relative redirect to: $nextUri');
        
        await _preResolveIPv4(nextUri.host);
        final nextReq = await _client.getUrl(nextUri);
        nextReq.followRedirects = false;
        nextReq.contentLength = -1;
        nextReq.headers.chunkedTransferEncoding = false;
        
        clientReq.headers.forEach((name, values) {
          final lowerName = name.toLowerCase();
          if (lowerName != 'host' && lowerName != 'content-length') {
            bool isFirst = true;
            for (final val in values) {
              if (isFirst) {
                nextReq.headers.set(name, val);
                isFirst = false;
              } else {
                nextReq.headers.add(name, val);
              }
            }
          }
        });
        
        // Skip relative redirect headers logging
        // nextReq.headers.forEach((name, values) => debugPrint('  $name: ${values.join(", ")}'));
        
        relativeTargetUri = nextUri;
        clientResp = await nextReq.close();
        redirectCount++;
      }
      
      if (clientResp.statusCode >= 400) {
        final body = await clientResp.transform(utf8.decoder).join();
        debugPrint('[LocalStreamingProxy] Relative CDN Error body: $body');
        request.response.statusCode = clientResp.statusCode;
        request.response.headers.contentType = ContentType.text;
        request.response.write(body);
        await request.response.close();
        return;
      }

      request.response.statusCode = clientResp.statusCode;

      clientResp.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (!_skipResponseHeaders.contains(lower) && lower != 'content-type' && lower != 'content-range' && lower != 'content-length') {
          for (var value in values) {
            try {
              request.response.headers.add(name, value);
            } catch (_) {}
          }
        }
      });

      if (isTikTokSegment) {
        final contentRange = clientResp.headers.value('content-range');
        if (contentRange != null) {
          final rangeMatch = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
          if (rangeMatch != null) {
            final start = (int.parse(rangeMatch.group(1)!) - 70).clamp(0, 999999999999);
            final end = (int.parse(rangeMatch.group(2)!) - 70).clamp(0, 999999999999);
            final total = (int.parse(rangeMatch.group(3)!) - 70).clamp(0, 999999999999);
            request.response.headers.set('Content-Range', 'bytes $start-$end/$total');
          }
        }
        if (needStrip) {
          final lenStr = clientResp.headers.value('content-length');
          if (lenStr != null) {
            final len = int.parse(lenStr);
            request.response.headers.set('Content-Length', (len - 70).clamp(0, 999999999999).toString());
          }
        } else {
          final lenStr = clientResp.headers.value('content-length');
          if (lenStr != null) {
            request.response.headers.set('Content-Length', lenStr);
          }
        }
        request.response.headers.set('Content-Type', 'video/mp2t');
      } else {
        final cType = clientResp.headers.value('content-type') ?? 'video/mp4';
        request.response.headers.set('Content-Type', cType);
        final lenStr = clientResp.headers.value('content-length');
        if (lenStr != null) request.response.headers.set('Content-Length', lenStr);
        final contentRange = clientResp.headers.value('content-range');
        if (contentRange != null) request.response.headers.set('Content-Range', contentRange);
      }

      final cType = clientResp.headers.value('content-type') ?? 'video/mp4';
      if (targetUrl.toLowerCase().contains('.m3u8') || cType.toLowerCase().contains('mpegurl')) {
        final body = await clientResp.transform(utf8.decoder).join();
        final rewrittenBody = body.replaceAllMapped(RegExp(r'https://[^\s\r\n]+'), (match) {
          final originalUrl = match.group(0)!;
          final refParam = _lastReferer.isNotEmpty ? '&referer=${Uri.encodeComponent(_lastReferer)}' : '';
          return 'http://127.0.0.1:$_port/play.ts?url=${Uri.encodeComponent(originalUrl)}$refParam';
        });
        request.response.headers.set('Content-Type', 'application/vnd.apple.mpegurl');
        request.response.headers.chunkedTransferEncoding = false;
        request.response.headers.contentLength = utf8.encode(rewrittenBody).length;
        request.response.write(rewrittenBody);
        await request.response.close();
        debugPrint('[LocalStreamingProxy] Finished relative streaming rewritten m3u8');
      } else if (isTikTokSegment && needStrip) {
        int bytesRead = 0;
        bool stripped = false;
        await for (var chunk in clientResp) {
          if (!stripped) {
            if (bytesRead + chunk.length > 70) {
              final sliceOffset = 70 - bytesRead;
              request.response.add(chunk.sublist(sliceOffset));
              stripped = true;
            }
            bytesRead += chunk.length;
          } else {
            request.response.add(chunk);
          }
        }
        await request.response.close();
        debugPrint('[LocalStreamingProxy] Finished relative streaming stripped segment');
      } else {
        bool clientGone = false;
        request.response.done.then((_) {
          clientGone = true;
        }).catchError((_) {
          clientGone = true;
        });
        try {
          await for (final chunk in clientResp) {
            if (clientGone) {
              return;
            }
            request.response.add(chunk);
            await request.response.flush();
          }
        } catch (_) {
        } finally {
          if (!clientGone) {
            try {
              await request.response.close();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalStreamingProxy] Relative proxy error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
    _lastBaseUrl = '';
    debugPrint('[LocalStreamingProxy] Stopped internal proxy server');
  }
}
