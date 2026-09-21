import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class ScreenshotManager {
  int port;
  final String host;
  final String basePath;

  ScreenshotManager({
    required this.port,
    required this.host,
    this.basePath = "screenshots",
  }) {
    _client = HttpClient();
  }

  final Map<String, List<int>> _screenshots = {};
  late final HttpClient _client;

  bool _disposed = false;

  Future<void> pumpAndScreenshot(
    String filename,
    WidgetTester tester,
    IntegrationTestWidgetsFlutterBinding binding,
  ) async {
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    await takeScreenshot(filename, binding);
  }

  Future<void> takeScreenshot(
    String filename,
    IntegrationTestWidgetsFlutterBinding binding,
  ) async {
    final screenshotBytes = await binding.takeScreenshot("screenshot");
    var screenshotName = filename.replaceAll(" ", "_").toLowerCase();

    _screenshots[screenshotName] = screenshotBytes;
  }

  Future<void> uploadScreenshots(String screenshotNamespace) async {
    final sanetizedNamespace = screenshotNamespace
        .replaceAll(" ", "_")
        .toLowerCase();

    try {
      await Future.wait(
        _screenshots.entries.map((entry) async {
          final (screenshotName, screenshotBytes) = (entry.key, entry.value);
          final request = await _client.post(
            host,
            port,
            "screenshots/$basePath/$sanetizedNamespace/$screenshotName.png",
          );
          request
            ..contentLength = screenshotBytes.length
            ..add(screenshotBytes);

          final response = await request.close();
          await response.drain();

          if (response.statusCode != 200) {
            throw Exception(
              "Failed to upload screenshot: ${response.statusCode}",
            );
          }
        }),
      );
    } catch (e) {
      _client.close();
      throw Exception("Error uploading screenshots: $e");
    }
  }

  void clear() {
    _screenshots.clear();
  }

  void dispose() {
    if (_disposed) return;

    _client.close();
    clear();

    _disposed = true;
  }
}
