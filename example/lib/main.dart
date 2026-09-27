import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final analytics = await createUmamiAnalytics(
    const FlutterUmamiConfig(
      websiteId: 'your-website-id',
      endpoint: 'https://your-umami-instance.com',
      hostname: 'myapp.com',
      userId: 'user-123',
      // SQLite on Android / iOS / desktop, localStorage on web.
      queueConfig: UmamiQueueConfig.persisted(maxSize: 500),
      logger: UmamiLogger(minLevel: UmamiLogLevel.debug),
      // Adds platform, OS, app version and browser to trackEvent data.
      attachDeviceData: true,
    ),
    recordFirstOpen: true,
  );

  runApp(MyApp(analytics: analytics));
}

class MyApp extends StatefulWidget {
  final FlutterUmamiAnalytics analytics;
  const MyApp({super.key, required this.analytics});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.analytics.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(widget.analytics.flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Umami Demo',
      navigatorObservers: [
        UmamiNavigatorObserver(
          collector: widget.analytics.collector,
          routeFilter: (route) => route.settings.name != '/login',
          routeNameMapper: (route) {
            final name = route.settings.name;
            return name != null ? '/app$name' : null;
          },
        ),
      ],
      home: HomeScreen(analytics: widget.analytics),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final FlutterUmamiAnalytics analytics;
  const HomeScreen({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Umami Analytics Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                analytics.trackEvent(
                  name: 'button_click',
                  data: {'button': 'primary', 'screen': 'home'},
                );
              },
              child: const Text('Track Event'),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                analytics.trackPageView(url: '/custom-page');
              },
              child: const Text('Track Page View'),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                analytics.identify(
                  properties: {'tier': 'premium', 'plan': 'enterprise'},
                );
              },
              label: const Text('Identify User'),
            ),
          ],
        ),
      ),
    );
  }
}
