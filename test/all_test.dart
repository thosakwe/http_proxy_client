import 'dart:io';
import 'package:angel_common/angel_common.dart';
import 'package:http_proxy_client/http_proxy_client.dart' as http;
import 'package:test/test.dart';

main() {
  http.ProxyClient client;
  HttpServer server;

  setUp(() async {
    server = await createServer().startServer();
    client = new http.ProxyClient([
      new http.ProxyEndpoint(host: server.address.address, port: server.port)
    ]);
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
    client = null;
    server = null;
  });

  test('Basic', () async {
    var res = await client.get('https://pub.dartlang.org');
    print('Response: ${res.body}');
  });
}

Angel createServer() {
  var app = new Angel()..storeOriginalBuffer = true;
  var client = new HttpClient();

  app.before.add((RequestContext req, ResponseContext res) async {
    var rq = await client.openUrl(req.method, req.uri);
    copyHeaders(req.io.headers, rq.headers);
    rq.add(req.originalBuffer);
    var rs = await rq.close();
    res.io.statusCode = rs.statusCode;
    copyHeaders(rs.headers, res.io.headers);
    await rs.pipe(res.io);
    res
      ..willCloseItself = true
      ..end();
    return false;
  });

  return app;
}
