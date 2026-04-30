// ignore_for_file: deprecated_member_use

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
  static const primaryL = Color(0xFFFFEDD5);
  static const primaryD = Color(0xFFEA580C);
  static const danger   = Color(0xFFDC2626);
  static const success  = Color(0xFF16A34A);
  static const successB = Color(0xFFDCFCE7);
}

// ─────────────────────────────────────────────────────────────────────────────
// GRANT POINTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class GrantPointsScreen extends StatefulWidget {
  const GrantPointsScreen({super.key});

  @override
  State<GrantPointsScreen> createState() => _GrantPointsScreenState();
}

class _GrantPointsScreenState extends State<GrantPointsScreen> {
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
  int get _toAdd         => int.tryParse(_pointsCtrl.text) ?? 0;
  bool get _canAward     => _matched != null && _toAdd > 0 && !_loading;

  // Mobile hint state
  _HintState get _mobileHint {
    if (_fetching) return _HintState.loading;
    final len = _mobileCtrl.text.length;
    if (len == 0) return _HintState.none;
    if (len < 10) return _HintState.partial;
    return _matched != null ? _HintState.found : _HintState.notFound;
  }

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

  Future<void> _award() async {
    if (!_canAward) return;
    setState(() => _loading = true);

    try {
      final newPoints = _currentPoints + _toAdd;
      final res = await http.put(
        Uri.parse('$_api/updatePoints/${_matched!['CustomerID']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'points': newPoints}),
      );

      if (res.statusCode == 200) {
        final awarded = _toAdd;
        setState(() {
          _customers = _customers.map((c) =>
            c['CustomerID'] == _matched!['CustomerID']
              ? {...c, 'CustomerPoints': newPoints}
              : c,
          ).toList();
        });
        _mobileCtrl.clear();
        _pointsCtrl.clear();
        _toast('$awarded points awarded successfully');
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
      backgroundColor: error ? T.danger : T.success,
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
                _buildTitle(),
                const SizedBox(height: 36),
                _buildMobileField(),
                const SizedBox(height: 20),
                _buildPointsField(),
                if (_matched != null) ...[
                  const SizedBox(height: 20),
                  _buildPreviewCard(),
                ],
                const SizedBox(height: 28),
                _buildAwardButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Grant Points',
          style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.w800,
            color: T.navy, letterSpacing: -0.8,
          )),
      const SizedBox(height: 6),
      const Text('Search by mobile to validate and apply rewards.',
          style: TextStyle(fontSize: 14, color: T.muted)),
      const SizedBox(height: 20),
      Container(height: 1, color: T.faint),
    ]);
  }

  Widget _buildMobileField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Mobile Number'),
      const SizedBox(height: 8),
      _InputBox(
        controller: _mobileCtrl,
        hint: '10-digit mobile number',
        keyboardType: TextInputType.number,
        enabled: !_fetching && !_loading,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
      ),
      const SizedBox(height: 8),
      _buildMobileHint(),
    ]);
  }

  Widget _buildMobileHint() {
    switch (_mobileHint) {
      case _HintState.loading:
        return _hintRow(Icons.hourglass_empty_rounded, 'Loading database...', T.muted);
      case _HintState.partial:
        return _hintRow(Icons.info_outline_rounded, 'Requires 10 digits', T.muted);
      case _HintState.found:
        return _hintRow(Icons.check_circle_outline_rounded, 'Customer verified', T.success);
      case _HintState.notFound:
        return _hintRow(Icons.cancel_outlined, 'Customer not found', T.danger);
      case _HintState.none:
        return const SizedBox.shrink();
    }
  }

  Widget _hintRow(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  Widget _buildPointsField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Points to Award'),
      const SizedBox(height: 8),
      _InputBox(
        controller: _pointsCtrl,
        hint: 'e.g. 50',
        keyboardType: TextInputType.number,
        enabled: _matched != null && !_loading,
        formatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    ]);
  }

  Widget _buildPreviewCard() {
    final showCalc = _toAdd > 0;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.faint),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Customer name + ID
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              _matched?['CustomerName'] ?? '',
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: T.navy,
              ),
            ),
            Text(
              '#CUST-${_matched?['CustomerID']}',
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12,
                color: T.muted, fontWeight: FontWeight.w600,
              ),
            ),
          ]),

          const SizedBox(height: 16),
          Container(height: 1, color: T.faint),
          const SizedBox(height: 16),

          if (!showCalc)
            // Just balance
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Current Balance',
                  style: TextStyle(fontSize: 13, color: T.muted)),
              Text('$_currentPoints pts',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: T.navy,
                  )),
            ])
          else ...[
            // Calculation row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Calculation',
                  style: TextStyle(fontSize: 13, color: T.muted)),
              Row(children: [
                _PtChip(label: '$_currentPoints pts', bg: T.bg),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('+', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: T.muted,
                  )),
                ),
                _PtChip(label: '$_toAdd pts', bg: T.primaryL, textColor: T.primaryD),
              ]),
            ]),
            const SizedBox(height: 14),
            // New balance row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('New Balance',
                  style: TextStyle(fontSize: 13, color: T.muted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                color: T.navy,
                child: Text(
                  '${_currentPoints + _toAdd} pts',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.3,
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _buildAwardButton() {
    return _AwardBtn(canAward: _canAward, loading: _loading, onTap: _award);
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: T.muted, letterSpacing: 1.2,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

enum _HintState { none, loading, partial, found, notFound }

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool enabled;
  final List<TextInputFormatter> formatters;

  const _InputBox({
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
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        enabled: enabled,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: T.navy),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: T.faint, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _PtChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const _PtChip({
    required this.label,
    required this.bg,
    this.textColor = T.navy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: bg,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: textColor,
        ),
      ),
    );
  }
}

class _AwardBtn extends StatefulWidget {
  final bool canAward;
  final bool loading;
  final VoidCallback onTap;
  const _AwardBtn({required this.canAward, required this.loading, required this.onTap});

  @override
  State<_AwardBtn> createState() => _AwardBtnState();
}

class _AwardBtnState extends State<_AwardBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.canAward;
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
              ? const [BoxShadow(color: T.primaryD, offset: Offset(0, 3), blurRadius: 0)]
              : [],
        ),
        child: Center(
          child: widget.loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded,
                      color: active ? Colors.white : T.muted, size: 18),
                  const SizedBox(width: 8),
                  Text('Confirm & Award',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: active ? Colors.white : T.muted,
                        letterSpacing: 0.3,
                      )),
                ]),
        ),
      ),
    );
  }
}

