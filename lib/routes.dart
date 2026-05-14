import 'package:flutter/material.dart';

import 'package:petropoints/screens/dashboard.dart';
import 'package:petropoints/screens/award_points.dart';
import 'package:petropoints/screens/redeem_points.dart';
import 'package:petropoints/screens/customers.dart';
import 'package:petropoints/screens/homepage.dart';

class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String awardPoints = '/award';
  static const String customers = '/customers';
  static const String redeem = '/redeem';
  static const String homepage = '/homepage';
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.homepage:
        return MaterialPageRoute(builder: (_) => const HomepageScreen());

      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());

      case AppRoutes.awardPoints:
        return MaterialPageRoute(builder: (_) => const AwardPointsScreen());

      case AppRoutes.redeem:
        return MaterialPageRoute(builder: (_) => const RedeemPointsScreen());

      case AppRoutes.customers:
        return MaterialPageRoute(builder: (_) => const CustomersScreen());

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
