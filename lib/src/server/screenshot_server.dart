// ignore_for_file: avoid_print

import 'dart:io';

Future<void> runScreenshotServer({int port = 3824}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Screenshot server running on http://127.0.0.1:$port');

  await for (HttpRequest request in server) {
    print('Request: ${request.method} ${request.uri}');
    print('Headers: ${request.headers}');

    if (request.method == 'GET' && request.uri.path == '/health') {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('true')
        ..close();
    } else if (request.method == 'POST' &&
        request.uri.path.startsWith('/screenshots/') &&
        !request.uri.pathSegments.contains('..')) {
      final screenshotPath = request.uri.pathSegments.skip(1).join('/');
      final file = File(screenshotPath);

      await file.create(recursive: true);
      await file.writeAsBytes(
        await request.fold<List<int>>(
          [],
          (buffer, data) => buffer..addAll(data),
        ),
      );

      request.response
        ..statusCode = HttpStatus.ok
        ..write('Screenshot saved as $screenshotPath')
        ..close();

      print('Saved: $screenshotPath');
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found')
        ..close();
    }
  }
}
