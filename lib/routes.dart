// routes.dart
import 'package:flutter/material.dart';
import 'package:petropoints/awards.dart';
import 'package:petropoints/customer.dart';
import 'package:petropoints/redeem.dart';
import 'package:petropoints/homepage.dart';
class AppRoutes {
  static const String grantPoints = '/grant-points';
  static const String dashboard = '/dashboard';
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