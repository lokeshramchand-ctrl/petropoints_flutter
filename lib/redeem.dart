// ignore_for_file: deprecated_member_use, unnecessary_brace_in_string_interps

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────

class T {
  static const bg       = Color(0xFFF8FAFC);
  static const surface  = Color(0xFFFFFFFF);
  static const navy     = Color(0xFF0F172A);
  static const muted    = Color(0xFF64748B);
  static const faint    = Color(0xFFCBD5E1);
  static const primary  = Color(0xFFF97316);
  static const danger   = Color(0xFFDC2626);
  static const successT = Color(0xFF166534);
  static const successB = Color(0xFFDCFCE7);
}

// ─────────────────────────────────────────────────────────────────────────────
// REDEEM SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RedeemPointsScreen extends StatefulWidget {
  const RedeemPointsScreen({super.key});

  @override
  State<RedeemPointsScreen> createState() => _RedeemPointsScreenState();
}

class _RedeemPointsScreenState extends State<RedeemPointsScreen> {
  static const _api = 'https://petropoints-backend.deploy.splsystems.in/api';

  List<dynamic> _customers = [];
  bool _fetching = true;
  bool _loading  = false;

  final _mobileCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();

  Map<String, dynamic>? get _matched => _customers.firstWhere(
    (c) => c['CustomerMobile']?.toString() == _mobileCtrl.text,
    orElse: () => null,
  );

  int get _currentPoints => int.tryParse(_matched?['CustomerPoints']?.toString() ?? '0') ?? 0;
  int get _toRedeem      => int.tryParse(_pointsCtrl.text) ?? 0;
  bool get _insufficient => _matched != null && _toRedeem > _currentPoints;
  bool get _canRedeem    =>
      _matched != null && _toRedeem > 0 && !_insufficient && !_loading;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _mobileCtrl.addListener(() => setState(() {}));
    _pointsCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final res = await http.get(Uri.parse('$_api/read'));
      if (res.statusCode == 200) {
        setState(() => _customers = json.decode(res.body));
      }
    } catch (_) {
      _toast('Failed to load customers', error: true);
    } finally {
      setState(() => _fetching = false);
    }
  }

  Future<void> _redeem() async {
    if (!_canRedeem) return;
    setState(() => _loading = true);

    try {
      final newPoints = _currentPoints - _toRedeem;
      final res = await http.put(
        Uri.parse('$_api/updatePoints/${_matched!['CustomerID']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'points': newPoints}),
      );

      if (res.statusCode == 200) {
        setState(() {
          _customers = _customers.map((c) =>
            c['CustomerID'] == _matched!['CustomerID']
              ? {...c, 'CustomerPoints': newPoints}
              : c,
          ).toList();
        });
        _mobileCtrl.clear();
        _pointsCtrl.clear();
        _toast('${_toRedeem} points redeemed successfully');
      } else {
        throw Exception();
      }
    } catch (_) {
      _toast('Something went wrong. Try again.', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: error ? T.danger : T.successT,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(20),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageTitle(),
                const SizedBox(height: 36),
                _buildMobileField(),
                if (_matched != null) ...[
                  const SizedBox(height: 20),
                  _buildCustomerCard(),
                ],
                const SizedBox(height: 20),
                _buildPointsField(),
                if (_insufficient) ...[
                  const SizedBox(height: 10),
                  _buildInsufficientWarning(),
                ],
                const SizedBox(height: 28),
                _buildRedeemButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildPageTitle() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Redeem Points',
          style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.w800,
            color: T.navy, letterSpacing: -0.8,
          )),
      const SizedBox(height: 6),
      const Text('Deduct points from a customer account.',
          style: TextStyle(fontSize: 14, color: T.muted)),
      const SizedBox(height: 20),
      Container(height: 1, color: T.faint),
    ]);
  }

  Widget _buildMobileField() {
    return _Field(
      label: 'Mobile Number',
      child: _Input(
        controller: _mobileCtrl,
        hint: '10-digit mobile number',
        keyboardType: TextInputType.number,
        enabled: !_fetching && !_loading,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return AnimatedOpacity(
      opacity: _matched != null ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.faint),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(children: [
          _InfoRow(
            label: 'Name',
            value: _matched?['CustomerName'] ?? '—',
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: 'Balance',
            value: '$_currentPoints pts',
            valueStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: T.navy,
              letterSpacing: -0.5,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPointsField() {
    return _Field(
      label: 'Points to Redeem',
      child: _Input(
        controller: _pointsCtrl,
        hint: 'e.g. 50',
        keyboardType: TextInputType.number,
        enabled: _matched != null && !_loading,
        formatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  Widget _buildInsufficientWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFEF2F2),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 15, color: T.danger),
        const SizedBox(width: 8),
        const Text('Insufficient balance',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: T.danger,
            )),
      ]),
    );
  }

  Widget _buildRedeemButton() {
    return _RedeemBtn(
      canRedeem: _canRedeem,
      loading: _loading,
      onTap: _redeem,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: T.muted, letterSpacing: 1.2,
          )),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool enabled;
  final List<TextInputFormatter> formatters;

  const _Input({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.enabled,
    required this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? T.surface : const Color(0xFFF1F5F9),
        border: Border.all(color: T.faint),
      ),
      child: Focus(
        child: Builder(builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              border: Border.all(
                color: focused ? T.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: formatters,
              enabled: enabled,
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: T.navy,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: T.faint, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 13, color: T.muted, fontWeight: FontWeight.w500,
            )),
        Text(value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: T.navy,
                )),
      ],
    );
  }
}

class _RedeemBtn extends StatefulWidget {
  final bool canRedeem;
  final bool loading;
  final VoidCallback onTap;
  const _RedeemBtn({required this.canRedeem, required this.loading, required this.onTap});

  @override
  State<_RedeemBtn> createState() => _RedeemBtnState();
}

class _RedeemBtnState extends State<_RedeemBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.canRedeem;

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) { setState(() => _pressed = false); widget.onTap(); } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed ? (Matrix4.identity()..translate(1.0, 1.0)) : Matrix4.identity(),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? T.primary : T.faint,
          borderRadius: BorderRadius.circular(2),
          boxShadow: active && !_pressed
              ? const [BoxShadow(color: Color(0xFFEA580C), offset: Offset(0, 3), blurRadius: 0)]
              : [],
        ),
        child: Center(
          child: widget.loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5,
                  ),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_rounded,
                      color: active ? Colors.white : T.muted, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm & Redeem',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : T.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}
