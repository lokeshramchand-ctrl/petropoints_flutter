// routes.dart
import 'package:flutter/material.dart';
import 'package:petropoints/homepage.dart';


class AppRoutes {
  static const String grantPoints = '/award';
  static const String dashboard = '/DashboardScreen';
  static const String customers = '/customers';
  static const String redeem = '/redeem';
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
        case AppRoutes.dashboard:
          return MaterialPageRoute(builder: (_) => const DashboardScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}