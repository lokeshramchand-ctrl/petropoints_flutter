import 'package:flutter/material.dart';
import 'package:petropoints/routes.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.homepage,
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
