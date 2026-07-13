import 'package:tief_screen/src/server/screenshot_server.dart';

Future<void> main(List<String> args) async {
  await runScreenshotServer(
    port: int.parse(args.isNotEmpty ? args[0] : '3824'),
  );
}
