import 'package:flutter/material.dart';
import 'package:petropoints/routes.dart';

class HomepageScreen extends StatelessWidget {
  const HomepageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1,

              children: [

                _DashboardBlock(
                  title: 'Award Points',
                  icon: Icons.add_circle_outline,
                  color: const Color(0xFF1976D2),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.awardPoints,
                    );
                  },
                ),

                // REDEEM
                _DashboardBlock(
                  title: 'Redeem Points',
                  icon: Icons.redeem,
                  color: const Color(0xFFD32F2F),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.redeem,
                    );
                  },
                ),

                // CUSTOMERS
                _DashboardBlock(
                  title: 'Customers',
                  icon: Icons.people_outline,
                  color: const Color(0xFF388E3C),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.customers,
                    );
                  },
                ),

                // DASHBOARD / REPORTS
                _DashboardBlock(
                  title: 'Dashboard',
                  icon: Icons.bar_chart,
                  color: const Color(0xFFF57C00),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.dashboard,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _DashboardBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardBlock({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,

      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,

        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.15),
            ),
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),

              const SizedBox(height: 16),

              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}