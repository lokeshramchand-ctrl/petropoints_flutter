// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page title
                const Text(
                  'Grant Points',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search by mobile to validate and apply rewards.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 24),

                // Mobile field
                _SimpleField(
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.number,
                  enabled: !_fetching && !_loading,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 6),
                _buildMobileHint(),

                const SizedBox(height: 16),

                // Points field
                _SimpleField(
                  label: 'Points to Award',
                  hint: 'e.g. 50',
                  controller: _pointsCtrl,
                  keyboardType: TextInputType.number,
                  enabled: _matched != null && !_loading,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),

                // Preview card
                if (_matched != null) ...[
                  const SizedBox(height: 16),
                  _buildPreviewCard(),
                ],

                const SizedBox(height: 24),

                // Award button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _canAward ? _award : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFBDBDBD),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Confirm & Award',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHint() {
    switch (_mobileHint) {
      case _HintState.loading:
        return _hintRow(Icons.hourglass_empty_rounded, 'Loading...', Colors.grey);
      case _HintState.partial:
        return _hintRow(Icons.info_outline_rounded, 'Requires 10 digits', Colors.grey);
      case _HintState.found:
        return _hintRow(Icons.check_circle_outline_rounded, 'Customer verified', Colors.green.shade700);
      case _HintState.notFound:
        return _hintRow(Icons.cancel_outlined, 'Customer not found', Colors.red.shade700);
      case _HintState.none:
        return const SizedBox.shrink();
    }
  }

  Widget _hintRow(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(fontSize: 13, color: color)),
    ]);
  }

  Widget _buildPreviewCard() {
    final showCalc = _toAdd > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Customer name + ID
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            _matched?['CustomerName'] ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(
            '#${_matched?['CustomerID']}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ]),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        if (!showCalc)
          // Just current balance
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Current Balance',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text(
              '$_currentPoints pts',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ])
        else ...[
          // Calculation
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Current Balance',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text('$_currentPoints pts',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Adding',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text(
              '+ $_toAdd pts',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('New Balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                )),
            Text(
              '${_currentPoints + _toAdd} pts',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

enum _HintState { none, loading, partial, found, notFound }

class _SimpleField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool enabled;
  final List<TextInputFormatter> inputFormatters;

  const _SimpleField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.enabled,
    required this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF333333),
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        enabled: enabled,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF1976D2)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
          ),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF5F5F5),
        ),
      ),
    ]);
  }
}