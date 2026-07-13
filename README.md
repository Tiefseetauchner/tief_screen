# tief_screen

> The one stop shop for Flutter widget screenshotting

When I first started writing my Flutter screenshot automation, I manually highlighted widgets and took screenshots. This wasn't only tedious, but also very verbose.

Thus, tief_screen was born. It is your friend when it comes to taking screenshots of your Flutter widgets, highlighting them, and sending them to a server.

## Why

In Flutter, taking a screenshot of a widget isn't straight forward. There is a lot of bug prone boilerplate that has to be written, and then, it only runs on some systems anyways. Importantly, it doesn't run on Linux.

So my solution was to spin up an emulator, run the app, and then take the screenshots. This also allows me to simulate actual devices, like an android phone, which is perfect for taking the screenshots for the App Store and Play Store.

Highlighting widgets also fell into the category of "This gotta be easier". I wrote the widget highlighter to do just that. It allows you to highlight parts of your screenshot with a simple API.

## The API I just talked about

Notably, tief_screen is not a screenshot testing library. It does not compare screenshots, nor does it care about them. It is a screenshot taking and management library, and it does that well.

There are two important things one needs to know about this library: The ScreenshotServer and the ScreenshotManager.

The ScreenshotServer is a standalone HTTP server that has one job: Get a request with bytes and write it to disk. Whatever you put in those bytes, it does not care. It's a simple server. And it's invoked via `dart run tief_screen:screenshot_server`, which makes it listen to port 3824 by default, but you can provide said port. When you do so, don't forget to also provide the same port to the ScreenshotManager, which is the other important part of this library.

The ScreenshotManager is the caller to that simple server. It exists to take screenshots, and then throw said screenshots at the server. It cares about the bytes, so it treats them well --- however, they remain in memory until the ScreenshotManager is disposed, so be careful with that. And beware that, as the HTTP Client is long lived for performance reasons, the ScreenshotManager *needs* to be disposed to close the connection and avoid uglyness.

An example of how to use the ScreenshotManager is as follows:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tief_screen/tief_screen.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Take screenshot of home screen", (WidgetTester tester) async {
    await tester.pumpWidget(MockApp(locale: locale.$2, child: HomeScreen()));
    await tester.pumpAndSettle();

    // 10.0.2.2 is not a random number --- it's the IP address of the host machine for an android emulator.
    final screenshotManager = ScreenshotManager(host: "10.0.2.2", port: 3824);

    await screenshotManager.pumpAndScreenshot(
      "home_screen_default",
      tester,
      binding,
    );

    await screenshotManager.uploadScreenshots("home_screen");

    screenshotManager.dispose();
  });
}
```

This is the simplets, one file example. Obviously, the ScreenshotServer must be running for this test to execute. It will save the screenshot as `screenshots/home_screen/home_screen_default.png`. But as soon as you have multiple screenshots, you should consider using the ScreenshotManager across multiple tests. As a simplified example:

```dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final screenshotManager = ScreenshotManager(host: "10.0.2.2", port: 3824);

  testWidgets("Take screenshot of home screen", (WidgetTester tester) async {
      await tester.pumpWidget(MockApp(child: HomeScreen()));

      await screenshotManager.pumpAndScreenshot(
        "home_screen_default",
        tester,
        binding,
      );
  });

  testWidgets("Take screenshot of home screen in dark mode", (WidgetTester tester) async {
      await tester.pumpWidget(MockApp(themeMode: ThemeMode.dark, child: HomeScreen()));

      await screenshotManager.pumpAndScreenshot(
        "home_screen_dark",
        tester,
        binding,
      );
  });

  tearDownAll(() async {
    await screenshotManager.uploadScreenshots("home_screen");
    screenshotManager.dispose();
  });
}
```

Note that, in these cases, the screenshotManager dies after the closure ends. The garbage collector will collect it.

But when taking a lot of repetative screenshots, you can reduce your memory footprint even further by using groups:

```dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final screenshotManager = ScreenshotManager(host: "10.0.2.2", port: 3824);

  for (final locale in kAllLocales) {
    group("Screenshots for $locale", () {      
      testWidgets("Take screenshot of home screen", (WidgetTester tester) async {
          await tester.pumpWidget(MockApp(locale: locale, child: HomeScreen()));

          await screenshotManager.pumpAndScreenshot(
            "home_screen_default",
            tester,
            binding,
          );
      });

      testWidgets("Take screenshot of home screen in dark mode", (WidgetTester tester) async {
          await tester.pumpWidget(
            MockApp(
              themeMode: ThemeMode.dark, 
              locale: locale, 
              child: HomeScreen()
            )
          );

          await screenshotManager.pumpAndScreenshot(
            "home_screen_dark",
            tester,
            binding,
          );
      });

      tearDownAll(() async {
        await screenshotManager.uploadScreenshots("$locale/home_screen");
        screenshotManager.clear();
      });
    });
  }

  screenshotManager.dispose();
}
```

This now creates a screenshot folder for each of the locales, e.g. `screenshots/en-US/home_screen/home_screen_default.png`. It also uploads screenshots early, clearing the backlog, which allows fails to produce some debug screenshots.

Furthermore, tief_screen is fully compatible with [tief_test_harness](https://github.com/Tiefseetauchner/tief_test_harness). When using a harness, you can improve the readability of the code even further:

```dart
ScenarioHarness getHarness({
  required ScreenshotManager screenshotManager
}) {
  ScenarioHarness(
    appContent: MockApp(child: HomeScreen()),
    afterEach: (tester, binding, ref, harnessName, scenarioName) async {
      await screenshotManager.pumpAndScreenshot(scenarioName, tester, binding);
    },
    afterAll: (binding, ref, harnessName) async {
      await screenshotManager.uploadScreenshots(harnessName);
      screenshotManager.dispose();
    }
  );
}

@RegisterHarness('HarnessRegistry1', name: "Home Screen")
Future<ScenarioHarness> buildHomeScreenHarness() async {
  final harness = getHarness(ScreenshotManager(host: "10.0.2.2", port: 3824));

  harness.addScenario(Scenario("Test Home Screen"));
  
  // ... More scenarios ...

  return harness;
}
```

You can even work more longely with a single screenshot manager by working with the harnessRunner:

```dart
// ----- main_harnesses_test.dart -----

import "main_harnesses_test.th.dart";

class _ScreenshotManagerState extends Notifier<ScreenshotManager?> {
  @override
  ScreenshotManager? build() => null;
  void initialize({required String host, int port = 3824}) => state = ScreenshotManager(host: host, port: port);
}

final screenshotManagerProvider = NotifierProvider<_ScreenshotManagerState, ScreenshotManager?>(
  _ScreenshotManagerState.new,
);

@GenerateHarnessRegistry("Main Harnesses")
Future<void> main() async {
  final harnesses = MarketingTabletHarnessRegistry().build();

  final harnessRunner = HarnessRunner(
    harnesses: harnesses,
    appBuilder: (child, _, __) => MaterialApp(home: child),
  );

  await harnessRunner.run(
    setUp: (binding, ref) {
      ref.read(screenshotManagerProvider.notifier).initialize("10.0.2.2");
    },
    tearDown: (binding, ref) {
      ref.read(screenshotManagerProvider).dispose();
    },
  );
}

// ----- my_first_harness.dart -----

ScenarioHarness getHarness() {
  ScenarioHarness(
    appContent: MockApp(child: HomeScreen()),
    afterEach: (tester, binding, ref, harnessName, scenarioName) async {
      await ref.read(screenshotManagerProvider).pumpAndScreenshot(scenarioName, tester, binding);
    },
    afterAll: (binding, ref, harnessName) async {
      final screenshotManager = ref.read(screenshotManagerProvider);

      await screenshotManager.uploadScreenshots(harnessName);
      screenshotManager.clear();
    }
  );
}

@RegisterHarness('Main Harnesses', name: "Home Screen")
Future<ScenarioHarness> buildHomeScreenHarness() async {
  final harness = getHarness();

  harness.addScenario(Scenario("Test Home Screen"));
  
  // ... More scenarios ...

  return harness;
}
```

However, this is crossing into documentation of the harness infrastructure, so we'll stop here. Note however the possibility to clear the screenshot managers internal state.

## Widget Highlighting

The secondary concern of screenshots is highlighting widgets. As highlighting widgets does not make sense without taking a screenshot of it afterwards, we probably agree that it has a reasonable spot in this here library.

Highlighting a widget is relatively straight forward:

```dart
await WidgetHighlighter(
  tester,
  defaultHighlightColor: Colors.red,
).highlightWidget(
  find.byTooltip("Whatever your tooltip is"),
  padding: 8,
);
```

You're effectively drawing a box around the element you wanted, with the default color and whatever padding.

Except this box? It has shadows.

There's also a multi-widget variant:

```dart
await WidgetHighlighter(
  tester,
  defaultHighlightColor: Colors.red,
).highlightWidgets(
  [find.byTooltip("Whatever your tooltip is"), find.byIcon(Icons.edit)],
  padding: 8,
);
```

It draws a box around multiple widgets, taking care to envelop all of them.

Both functions offer an optional `colorOverride` parameter, which is self explanatory.

## License

MIT. Look at [LICENSE](LICENSE) for details.

## Contributing

Gladly seen.

## Coffee

I need more coffee. Please.

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/tiefseetauchner)

