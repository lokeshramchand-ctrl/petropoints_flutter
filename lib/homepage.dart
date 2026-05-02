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

class T {
  static const Color bg       = Color(0xFFF1F5F7);
  static const Color surface  = Color(0xFFFFFFFF);
  static const Color ink      = Color(0xFF111827);
  static const Color muted    = Color(0xFF6B7280);
  static const Color accent   = Color(0xFF0D9488); // teal
  static const Color accentLt = Color(0xFFCCFBF1);
  static const Color warn     = Color(0xFFF59E0B);
  static const Color warnLt   = Color(0xFFFEF3C7);
  static const Color border   = Color(0xFFE5E7EB);
  static const Color ok       = Color(0xFF16A34A);
  static const Color okLt     = Color(0xFFDCFCE7);

  // Flat card — single border, tiny shadow only (1 dp — cheap)
  static BoxDecoration card({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      );
}


void main() => runApp(const PetroPointsApp());

class PetroPointsApp extends StatelessWidget {
  const PetroPointsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetroPoints',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: T.accent),
        scaffoldBackgroundColor: T.bg,
        fontFamily: 'Roboto', // bundled on every Android — zero extra memory
        appBarTheme: const AppBarTheme(
          backgroundColor: T.surface,
          foregroundColor: T.ink,
          surfaceTintColor: T.surface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: T.ink,
            letterSpacing: -0.3,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _apiUrl =
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
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse(_apiUrl));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final list = json.decode(res.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _customers = list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Derived values ──
  int get _total   => _customers.length;
  int get _active  => _customers.where((c) => c.points > 0).length;
  int get _zero    => _customers.where((c) => c.points == 0).length;
  int get _pts     => _customers.fold(0, (s, c) => s + c.points);
  List<Customer> get _recent => _customers.take(6).toList();

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: T.accent, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('PetroPoints'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh',
            onPressed: _fetchData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: T.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _fetchData)
              : _Body(
                  total: _total,
                  active: _active,
                  zero: _zero,
                  pts: _pts,
                  recent: _recent,
                ),
    );
  }
}

class _Body extends StatelessWidget {
  final int total, active, zero, pts;
  final List<Customer> recent;

  const _Body({
    required this.total,
    required this.active,
    required this.zero,
    required this.pts,
    required this.recent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
      // ListView is lazy — much cheaper than SingleChildScrollView + Column for long lists
      children: [
        // ── Summary banner ──
        _SummaryBanner(total: total, pts: pts),
        const SizedBox(height: 12),

        // ── Stats row (2 × 2 grid) ──
        _StatsGrid(total: total, active: active, pts: pts, zero: zero),
        const SizedBox(height: 16),

        // ── Section header ──
        _SectionHeader(title: 'Recent Customers', count: recent.length),
        const SizedBox(height: 8),

        // ── Customer list ──
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No customer data yet.',
                style: TextStyle(color: T.muted, fontSize: 13)),
          )
        else
          ...recent.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CustomerTile(customer: c),
              )),
      ],
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final int total, pts;
  const _SummaryBanner({required this.total, required this.pts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: T.card(color: T.accent),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('$total customers · ${_fmt(pts)} pts',
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}


class _StatsGrid extends StatelessWidget {
  final int total, active, pts, zero;
  const _StatsGrid(
      {required this.total,
      required this.active,
      required this.pts,
      required this.zero});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(Icons.people_alt_rounded,    'Total',   total.toString(),    T.accentLt, T.accent),
      _StatItem(Icons.verified_rounded,      'Active',  active.toString(),   T.okLt,     T.ok),
      _StatItem(Icons.stars_rounded,         'Points',  _fmt(pts),           T.warnLt,   T.warn),
      _StatItem(Icons.remove_circle_outline, 'No Pts',  zero.toString(),     T.border,   T.muted),
    ];

    // 2-column grid using Row + Expanded — no GridView overhead
    return Column(
      children: [
        Row(children: [
          Expanded(child: items[0]),
          const SizedBox(width: 10),
          Expanded(child: items[1]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: items[2]),
          const SizedBox(width: 10),
          Expanded(child: items[3]),
        ]),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color bg, fg;

  const _StatItem(this.icon, this.label, this.value, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: T.card(),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: T.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      color: T.ink,
                      fontWeight: FontWeight.w700,
                      height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: T.ink)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: T.accentLt, borderRadius: BorderRadius.circular(99)),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 11, color: T.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Customer Tile ────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final has = customer.points > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: T.card(),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: has ? T.accentLt : T.warnLt, shape: BoxShape.circle),
            child: Center(
              child: Text(
                _initials(customer.name),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: has ? T.accent : T.warn),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: T.ink)),
                Text(customer.id,
                    style: const TextStyle(fontSize: 11, color: T.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Points pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: has ? T.okLt : T.border,
                borderRadius: BorderRadius.circular(99)),
            child: Text(
              has ? '+${customer.points}' : '0',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: has ? T.ok : T.muted),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42, color: T.muted),
            const SizedBox(height: 12),
            const Text('Could not load data',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: T.ink)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: T.muted, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: T.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}