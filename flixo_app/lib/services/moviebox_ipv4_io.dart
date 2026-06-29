import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

HttpClient? _ipv4Client;
http.Client? _ipv4HttpClient;

/// Returns an IPv4-only HTTP client for Windows.
/// The CDN signs URLs bound to the requesting IP — both the download API
/// and the streaming proxy must use IPv4 to ensure matching IPs.
http.Client? getIPv4Client() {
  if (_ipv4HttpClient != null) return _ipv4HttpClient!;
  _ipv4Client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..badCertificateCallback = (cert, host, port) => true;
  _ipv4Client!.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
    final host = proxyHost ?? uri.host;
    final port = proxyPort ?? (uri.scheme == 'https' ? 443 : uri.port);
    try {
      final addrs = await InternetAddress.lookup(host, type: InternetAddressType.IPv4);
      if (addrs.isNotEmpty) {
        debugPrint('[MovieBox] IPv4 resolved $host -> ${addrs.first.address}');
        return Socket.startConnect(addrs.first, port);
      }
    } catch (_) {}
    return Socket.startConnect(host, port);
  };
  _ipv4HttpClient = IOClient(_ipv4Client!);
  return _ipv4HttpClient!;
}
