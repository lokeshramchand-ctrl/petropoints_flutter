// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Customer {
  final String id;
  final String name;
  final int points;

  const Customer({required this.id, required this.name, required this.points});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['CustomerID']?.toString() ?? '',
      name: json['CustomerName']?.toString() ?? 'Unknown',
      points: int.tryParse(json['CustomerPoints']?.toString() ?? '0') ?? 0,
    );
  }
}

class AppTheme {
  static const Color bgBody = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF0F766E);
  static const Color primarySoft = Color(0xFFD9F7F3);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF166534);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFB45309);
  static const Color warningBg = Color(0xFFFFF7ED);

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120F172A),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ],
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _apiUrl =
      'https://petropoints-backend.deploy.splsystems.in/api/read';

  List<Customer> _customers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      if (!mounted) return;

      setState(() {
        _customers = data
            .map((item) => Customer.fromJson(item as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  int get totalCustomers => _customers.length;
  int get totalPoints =>
      _customers.fold(0, (sum, customer) => sum + customer.points);
  int get activeCustomers =>
      _customers.where((customer) => customer.points > 0).length;
  int get zeroCustomers =>
      _customers.where((customer) => customer.points == 0).length;
  List<Customer> get recentCustomers => _customers.take(6).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBody,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: AppTheme.surface,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'PetroPoints',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMain,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.textMain,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _fetchData)
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth > 1100
                      ? 1100.0
                      : constraints.maxWidth;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeaderCard(
                              totalCustomers: totalCustomers,
                              totalPoints: totalPoints,
                              onRefresh: _fetchData,
                            ),
                            const SizedBox(height: 16),
                            _StatsGrid(
                              totalCustomers: totalCustomers,
                              activeCustomers: activeCustomers,
                              totalPoints: totalPoints,
                              zeroCustomers: zeroCustomers,
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Recent Customers',
                              subtitle:
                                  '${recentCustomers.length} latest entries',
                              child: recentCustomers.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text(
                                        'No customer data yet.',
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    )
                                  : GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount:
                                                constraints.maxWidth >= 900
                                                ? 2
                                                : constraints.maxWidth >= 600
                                                ? 2
                                                : 1,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio:
                                                constraints.maxWidth < 600
                                                ? 2.9
                                                : 3.4,
                                          ),
                                      itemCount: recentCustomers.length,
                                      itemBuilder: (context, index) {
                                        return _CustomerCard(
                                          customer: recentCustomers[index],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int totalCustomers;
  final int totalPoints;
  final VoidCallback onRefresh;

  const _HeaderCard({
    required this.totalCustomers,
    required this.totalPoints,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 640;
          if (stacked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simple customer dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textMain,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A clean view of customer points with a layout that works well on any screen size.',
                  style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MiniPill(
                      label: '$totalCustomers customers',
                      color: AppTheme.primarySoft,
                      textColor: AppTheme.primary,
                    ),
                    _MiniPill(
                      label: '$totalPoints points',
                      color: AppTheme.warningBg,
                      textColor: AppTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Simple customer dashboard',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A clean view of customer points with a layout that works well on any screen size.',
                      style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MiniPill(
                          label: '$totalCustomers customers',
                          color: AppTheme.primarySoft,
                          textColor: AppTheme.primary,
                        ),
                        _MiniPill(
                          label: '$totalPoints points',
                          color: AppTheme.warningBg,
                          textColor: AppTheme.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int totalCustomers;
  final int activeCustomers;
  final int totalPoints;
  final int zeroCustomers;

  const _StatsGrid({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.totalPoints,
    required this.zeroCustomers,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatTile(
        title: 'Total Customers',
        value: totalCustomers.toString(),
        icon: Icons.people_alt_rounded,
      ),
      _StatTile(
        title: 'Active Customers',
        value: activeCustomers.toString(),
        icon: Icons.verified_rounded,
      ),
      _StatTile(
        title: 'Total Points',
        value: _formatNumber(totalPoints),
        icon: Icons.stars_rounded,
      ),
      _StatTile(
        title: 'Zero Points',
        value: zeroCustomers.toString(),
        icon: Icons.remove_circle_outline_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
          ),
          itemBuilder: (context, index) => stats[index],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;

  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasPoints = customer.points > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasPoints ? AppTheme.primarySoft : AppTheme.warningBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: hasPoints ? AppTheme.primary : AppTheme.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  customer.id,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PointsChip(points: customer.points),
        ],
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  final int points;

  const _PointsChip({required this.points});

  @override
  Widget build(BuildContext context) {
    final hasPoints = points > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasPoints ? AppTheme.successBg : AppTheme.warningBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasPoints ? '+$points' : '0',
        style: TextStyle(
          color: hasPoints ? AppTheme.success : AppTheme.warning,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _MiniPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: AppTheme.warning,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[index]);
  }
  return buffer.toString();
}

void main() {
  runApp(const PetroPointsApp());
}

class PetroPointsApp extends StatelessWidget {
  const PetroPointsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetroPoints',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        scaffoldBackgroundColor: AppTheme.bgBody,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.textMain,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
