import 'package:flutter/material.dart';
import 'package:petropoints/customer.dart';
import 'package:petropoints/redeem.dart';
// import 'package:petropoints/homepage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // home: const DashboardScreen(),
      // home: const CustomersScreen(),
      home: const RedeemPointsScreen(),
      // home: const GrantPointsScreen(),
    );
  }
}
