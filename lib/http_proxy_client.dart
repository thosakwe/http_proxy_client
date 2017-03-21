import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

final RegExp _header =
    new RegExp(r'^([A-Za-z]+((A-Za-z-)*[A-Za-z-]+)?):\s*([^\n]+)$');
final RegExp _responseStart =
    new RegExp(r'^HTTP/[0-9]+\.[0-9]+ ([0-9]+) ([^\n]+)$');

/// Sends HTTP requests through a rotating list of proxy endpoints.
class ProxyClient extends http.BaseClient {
  http.IOClient _inner;
  final HttpClient _innerClient = new HttpClient();
  final math.Random _rnd = new math.Random();
  final List<ProxyEndpoint> _proxies = [];

  final StreamController<ProxyEndpoint> _onDead =
      new StreamController<ProxyEndpoint>();
  Stream<ProxyEndpoint> get onDead => _onDead.stream;

  ProxyClient([Iterable<ProxyEndpoint> endpoints]) {
    this._proxies.addAll(endpoints ?? []);

    for (var proxy in _proxies) {
      if (proxy.auth != null)
        _innerClient.addProxyCredentials(
            proxy.host,
            proxy.port,
            proxy.auth.realm,
            new HttpClientBasicCredentials(
                proxy.auth.username, proxy.auth.password));
    }

    _innerClient.findProxy = (_) {
      if (_proxies.isEmpty) return 'DIRECT';

      var buf = new StringBuffer();

      for (var proxy in _proxies) {
        var protocol = proxy.ssl == true ? 'https' : 'http';
        buf.write('PROXY ${proxy.host}:${proxy.port}');
      }

      return buf.toString().trim();
    };

    _inner = new http.IOClient(_innerClient);
  }

  @override
  void close() {
    _inner.close();
    _onDead.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }
}

class ProxyEndpoint {
  final String host;
  final ProxyEndpointAuth auth;
  final int port;
  final bool ssl;

  ProxyEndpoint({this.host, this.auth, this.port, this.ssl});
}

class ProxyEndpointAuth {
  String username, password, realm;
  ProxyEndpointAuth({this.username, this.password, this.realm});
}
