// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores, deprecated_member_use

import 'dart:convert';
import 'dart:isolate'; // OPT-2

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class Customer {
  final int id;
  final String name;
  final String city;
  final String mobile;
  final String aadhaar;
  final int points;

  const Customer({
    required this.id,
    required this.name,
    required this.city,
    required this.mobile,
    required this.aadhaar,
    required this.points,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: int.tryParse(json['CustomerID']?.toString() ?? '0') ?? 0,
        name: json['CustomerName']?.toString() ?? '',
        city: json['CustomerCity']?.toString() ?? '',
        mobile: (json['CustomerMobile']?.toString() ?? '').padLeft(10, '0'),
        aadhaar: json['CustomerAadhaar']?.toString() ?? '',
        points: int.tryParse(json['CustomerPoints']?.toString() ?? '0') ?? 0,
      );
}

// ─── Pre-computed view state ──────────────────────────────────────────────────
// OPT-1: All filtering, sorting, and per-row derived strings are computed ONCE
//        here — never inside build() or a getter called from build().

class FilteredState {
  // ignore: library_private_types_in_public_api
  final List<_RowData> rows;      // sorted, filtered, display-ready
  final List<Customer> all;       // full list kept for duplicate checks / ID math

  const FilteredState({required this.rows, required this.all});

  factory FilteredState.from(List<Customer> customers, String query) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? customers
        : customers
            .where((c) =>
                c.name.toLowerCase().contains(q) || c.mobile.contains(q))
            .toList(growable: false);

    // Sort once — not on every build tick.
    final sorted = [...filtered]..sort((a, b) => b.points.compareTo(a.points));

    return FilteredState(
      rows: sorted.map(_RowData.from).toList(growable: false),
      all: customers,
    );
  }
}

// OPT-1 / OPT-4: All display strings and booleans resolved at construction.
//                _CustomerRow.build() is pure layout — zero logic.
class _RowData {
  final int id;
  final String displayId;       // '#CUST-7821' — pre-built
  final String name;
  final String city;
  final String mobile;
  final String maskedAadhaar;   // OPT-1: masking done here, not in build()
  final String pointsLabel;
  final bool hasPoints;
  final bool isTop;             // points > 100

  const _RowData({
    required this.id,
    required this.displayId,
    required this.name,
    required this.city,
    required this.mobile,
    required this.maskedAadhaar,
    required this.pointsLabel,
    required this.hasPoints,
    required this.isTop,
  });

  factory _RowData.from(Customer c) {
    final a = c.aadhaar;
    final masked = a.length >= 4 ? '•••• •••• ${a.substring(a.length - 4)}' : a;
    return _RowData(
      id: c.id,
      displayId: '#CUST-${c.id}',
      name: c.name,
      city: c.city,
      mobile: c.mobile,
      maskedAadhaar: masked,
      pointsLabel: c.points.toString(),
      hasPoints: c.points > 0,
      isTop: c.points > 100,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME  — const decorations, no BoxShadow on runtime-rebuilt widgets (OPT-3)
// ═══════════════════════════════════════════════════════════════════════════════

class T {
  static const Color bg       = Color(0xFFF1F5F9);
  static const Color surface  = Color(0xFFFFFFFF);
  static const Color primary  = Color(0xFFF97316);
  static const Color primaryD = Color(0xFFEA580C);
  static const Color primaryL = Color(0xFFFFEDD5);
  static const Color navy     = Color(0xFF0F172A);
  static const Color muted    = Color(0xFF475569);
  static const Color faint    = Color(0xFF94A3B8);
  static const Color borderL  = Color(0xFFE2E8F0);
  static const Color danger   = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color successT = Color(0xFF166534);
  static const Color successB = Color(0xFFDCFCE7);

  // OPT-3: Static card used in stable containers (header band, table shell).
  //        Kept with shadow because it's painted once and never rebuilt.
  static BoxDecoration heavyCard({double bw = 2, Color? border, Color? bg}) =>
      BoxDecoration(
        color: bg ?? surface,
        border: Border.all(color: border ?? navy, width: bw),
        boxShadow: [BoxShadow(color: navy, offset: const Offset(4, 4), blurRadius: 0)],
      );

  // OPT-3: Flat card — used in widgets that rebuild on interaction (buttons,
  //        fields, rows). No BoxShadow → no GPU offscreen pass each frame.
  static const BoxDecoration flatCard = BoxDecoration(
    color: surface,
    border: Border.fromBorderSide(BorderSide(color: navy, width: 2)),
  );

  // OPT-3: Danger variant of flatCard — const, no shadow.
  static const BoxDecoration flatCardDanger = BoxDecoration(
    color: surface,
    border: Border.fromBorderSide(BorderSide(color: danger, width: 2)),
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w800,
    color: navy, letterSpacing: 1.5,
  );
  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'monospace', fontSize: 12,
    fontWeight: FontWeight.w700, color: navy,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATION REGEXPS  (BONUS FIX: hoisted as static const — not rebuilt per submit)
// ═══════════════════════════════════════════════════════════════════════════════

class _Validators {
  static final RegExp mobile  = RegExp(r'^[6-9]\d{9}$');
  static final RegExp aadhaar = RegExp(r'^\d{12}$');
}

// ═══════════════════════════════════════════════════════════════════════════════
// ISOLATE PARSE HELPER  (OPT-2)
// Top-level function — required by Isolate.run.
// ═══════════════════════════════════════════════════════════════════════════════

List<Customer> _parseCustomers(String body) {
  final list = json.decode(body) as List<dynamic>;
  return list
      .map((e) => Customer.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOMERS SCREEN
// OPT-4: State holds FilteredState (pre-computed). A separate ValueNotifier
//        drives the list so only ListView rebuilds on search changes — the
//        header, title, and stats strip are completely unaffected.
// ═══════════════════════════════════════════════════════════════════════════════

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const _api = 'https://petropoints-backend.deploy.splsystems.in/api';

  // OPT-4: Raw list kept only for mutation (add/delete) and duplicate checks.
  List<Customer> _allCustomers = [];

  // OPT-4: ValueNotifier drives the ListView independently of the outer state.
  final _filteredNotifier = ValueNotifier<FilteredState>(
    const FilteredState(rows: [], all: []),
  );

  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _filteredNotifier.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // OPT-1: Called once after any mutation — recomputes FilteredState and
  //        pushes it to the notifier. Never called from build().
  void _recompute() {
    _filteredNotifier.value = FilteredState.from(_allCustomers, _search);
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: isError ? T.danger : T.successT,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(20),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _fetchCustomers() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$_api/read'));
      if (res.statusCode == 200) {
        // OPT-2: JSON decode + map on a background isolate.
        final customers = await Isolate.run(() => _parseCustomers(res.body));
        // OPT-1: Derive view state here — not in build.
        _allCustomers = customers;
        _recompute();
      } else {
        _toast('Failed to load customers', isError: true);
      }
    } catch (_) {
      _toast('Network error', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCustomer(Map<String, String> fields) async {
    final nextId = _allCustomers.isEmpty
        ? 7821
        : _allCustomers.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;

    final res = await http.post(
      Uri.parse('$_api/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'id': nextId, 'name': fields['name'],
        'mobile': fields['mobile'], 'aadhar': fields['aadhaar'],
        'city': fields['city'],
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final newCustomer = Customer(
        id: nextId, name: fields['name']!, city: fields['city']!,
        mobile: fields['mobile']!, aadhaar: fields['aadhaar']!, points: 0,
      );
      _allCustomers = [..._allCustomers, newCustomer];
      _recompute(); // OPT-1: single recompute after mutation
      _toast('Customer added');
    } else {
      throw Exception('Failed');
    }
  }

  Future<void> _deleteCustomer(int id) async {
    final res = await http.delete(Uri.parse('$_api/delete/$id'));
    if (res.statusCode == 200) {
      _allCustomers = _allCustomers.where((c) => c.id != id).toList();
      _recompute(); // OPT-1: single recompute after mutation
      _toast('Customer deleted');
    } else {
      throw Exception('Failed');
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showAddDialog() {
    showDialog(
      context: context,
      barrierColor: T.navy.withOpacity(0.8),
      builder: (_) => _CustomerFormDialog(
        onSave: (fields) async {
          if (_allCustomers.any((c) => c.mobile == fields['mobile'])) {
            _toast('Mobile number already exists', isError: true);
            return;
          }
          await _addCustomer(fields);
        },
      ),
    );
  }

  void _showDeleteDialog(_RowData row) {
    showDialog(
      context: context,
      barrierColor: T.navy.withOpacity(0.8),
      builder: (_) => _DeleteDialog(
        displayId: row.displayId,
        customerId: row.id,
        onConfirm: () async => await _deleteCustomer(row.id),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  // OPT-4: build() is now nearly empty — all branching happens in child widgets.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // OPT-4 + OPT-5: Header is a const-constructable widget; RepaintBoundary
          //                 ensures search-driven rebuilds never touch it.
          RepaintBoundary(
            child: _HeaderSection(
              onAddTap: _showAddDialog,
              onSearch: (v) {
                _search = v;
                _recompute(); // OPT-1: push new FilteredState to notifier
              },
              searchCtrl: _searchCtrl,
            ),
          ),
          Expanded(
            child: _loading
                ? const _SkeletonList()
                // OPT-4: ValueListenableBuilder — only the table rebuilds on
                //        search changes. Header is fully isolated.
                : ValueListenableBuilder<FilteredState>(
                    valueListenable: _filteredNotifier,
                    builder: (_, state, __) {
                      if (state.rows.isEmpty) return const _EmptyState();
                      return _CustomerTable(
                        rows: state.rows,
                        onDelete: _showDeleteDialog,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER SECTION  (OPT-4: extracted, never rebuilt by search or hover)
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderSection extends StatelessWidget {
  final VoidCallback onAddTap;
  final ValueChanged<String> onSearch;
  final TextEditingController searchCtrl;

  const _HeaderSection({
    required this.onAddTap,
    required this.onSearch,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      color: T.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CUSTOMERS',
              style: TextStyle(
                fontSize: 38, fontWeight: FontWeight.w900,
                color: T.navy, letterSpacing: -1.5, height: 1,
              )),
          const SizedBox(height: 6),
          const Text('Manage your client directory and records',
              style: TextStyle(fontSize: 15, color: T.muted)),
          const SizedBox(height: 20),
          const SizedBox(height: 3, child: ColoredBox(color: T.navy)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _SearchField(
              controller: searchCtrl,
              onChanged: onSearch,
            )),
            const SizedBox(width: 16),
            _HardButton(label: 'ADD CUSTOMER', icon: Icons.add, onTap: onAddTap),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOMER TABLE  (OPT-4: receives pre-computed rows, does no work itself)
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomerTable extends StatelessWidget {
  final List<_RowData> rows;
  final void Function(_RowData) onDelete;

  const _CustomerTable({required this.rows, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      decoration: T.heavyCard(), // heavy shadow OK — painted once, not rebuilt
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: T.bg,
            border: Border(bottom: BorderSide(color: T.navy, width: 2)),
          ),
          child: const Row(children: [
            _TH('CUST ID', flex: 2),
            _TH('NAME', flex: 3),
            _TH('CITY', flex: 2),
            _TH('MOBILE', flex: 3),
            _TH('AADHAAR', flex: 3),
            _TH('POINTS', flex: 2),
            _TH('', flex: 1),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) =>
                // OPT-5: Each row is an isolated repaint boundary. Hovering
                //        row 3 repaints only row 3 — not the entire list.
                RepaintBoundary(
                  key: ValueKey(rows[i].id),
                  child: _CustomerRow(
                    row: rows[i],
                    isEven: i.isEven,
                    onDelete: () => onDelete(rows[i]),
                  ),
                ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TABLE ROW  (OPT-4: build() is pure layout — receives _RowData, no logic)
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomerRow extends StatefulWidget {
  final _RowData row;
  final bool isEven;
  final VoidCallback onDelete;

  const _CustomerRow({
    required this.row,
    required this.isEven,
    required this.onDelete,
  });

  @override
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    // build() = pure layout. All display strings came from _RowData constructor.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        // OPT-3: No BoxShadow here — AnimatedContainer rebuilds on hover.
        decoration: BoxDecoration(
          color: _hovered
              ? T.bg
              : (widget.isEven ? T.surface : const Color(0xFFFAFAFA)),
          border: const Border(bottom: BorderSide(color: T.borderL, width: 1)),
        ),
        child: Row(children: [
          // ID chip
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            // OPT-3: const border decoration, no shadow
            decoration: const BoxDecoration(
              color: T.bg,
              border: Border.fromBorderSide(BorderSide(color: T.borderL)),
            ),
            child: Text(r.displayId, style: T.monoStyle,
                overflow: TextOverflow.ellipsis),
          )),
          const SizedBox(width: 12),
          // Name
          Expanded(flex: 3, child: Text(r.name,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: T.navy),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // City
          Expanded(flex: 2, child: Text(r.city,
              style: const TextStyle(fontSize: 14, color: T.muted),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // Mobile
          Expanded(flex: 3, child: Text(r.mobile,
              style: const TextStyle(fontSize: 14, color: T.muted),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // Aadhaar — OPT-1: already masked in _RowData.from()
          Expanded(flex: 3, child: Text(r.maskedAadhaar,
              style: const TextStyle(fontSize: 14, color: T.muted,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // Points
          Expanded(flex: 2, child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: r.hasPoints ? T.successB : T.bg,
                border: Border.all(
                  color: r.hasPoints ? T.successT : T.navy, width: 1),
              ),
              child: Text(r.pointsLabel,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: r.hasPoints ? T.successT : T.navy,
                  )),
            ),
            if (r.isTop) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const BoxDecoration(
                  color: T.primaryL,
                  border: Border.fromBorderSide(
                      BorderSide(color: T.primary, width: 1)),
                ),
                child: const Text('TOP',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                        color: T.primaryD, letterSpacing: 1)),
              ),
            ],
          ])),
          // Delete button — AnimatedOpacity on hover
          Expanded(flex: 1, child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: _IconBtn(
                icon: Icons.delete_outline_rounded,
                color: T.danger,
                hoverBg: T.dangerBg,
                onTap: widget.onDelete,
              ),
            ),
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADD CUSTOMER DIALOG
// BONUS FIX: Controllers stored in a Map — single dispose() loop.
//            Validators are static const (not reconstructed per submit).
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomerFormDialog extends StatefulWidget {
  final Future<void> Function(Map<String, String>) onSave;
  const _CustomerFormDialog({required this.onSave});

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  // BONUS FIX: One Map instead of 4 loose controllers.
  final _ctrls = {
    'name':    TextEditingController(),
    'city':    TextEditingController(),
    'mobile':  TextEditingController(),
    'aadhaar': TextEditingController(),
  };

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose(); // single loop
    super.dispose();
  }

  String _val(String key) => _ctrls[key]!.text.trim();

  Future<void> _submit() async {
    final name    = _val('name');
    final city    = _val('city');
    final mobile  = _val('mobile');
    final aadhaar = _val('aadhaar');

    if (name.isEmpty) return setState(() => _error = 'Name is required');
    if (city.isEmpty) return setState(() => _error = 'City is required');
    // BONUS FIX: static final regexps — not reconstructed on each call
    if (!_Validators.mobile.hasMatch(mobile))
      return setState(() => _error = 'Enter valid 10-digit mobile');
    if (!_Validators.aadhaar.hasMatch(aadhaar))
      return setState(() => _error = 'Enter valid 12-digit Aadhaar');

    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave({'name': name, 'city': city,
          'mobile': mobile, 'aadhaar': aadhaar});
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() { _saving = false; _error = 'Request failed. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        // Dialog painted once — heavy shadow is fine here.
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.navy, width: 3),
          boxShadow: const [
            BoxShadow(color: T.primary, offset: Offset(12, 12), blurRadius: 0)
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('ADD NEW CUSTOMER',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                      color: T.navy, letterSpacing: 0.5)),
              _IconBtn(icon: Icons.close, color: T.muted,
                  onTap: () => Navigator.of(context).pop()),
            ]),
            const SizedBox(height: 4),
            const SizedBox(height: 2, child: ColoredBox(color: T.navy)),
            const SizedBox(height: 28),

            _FormField(label: 'FULL LEGAL NAME', hint: 'e.g. Jane Doe',
                controller: _ctrls['name']!),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _FormField(label: 'CITY', hint: 'e.g. Hyderabad',
                  controller: _ctrls['city']!)),
              const SizedBox(width: 16),
              Expanded(child: _FormField(
                label: 'MOBILE', hint: '10-digit number',
                controller: _ctrls['mobile']!,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              )),
            ]),
            const SizedBox(height: 20),
            _FormField(
              label: 'AADHAAR', hint: '12-digit number',
              controller: _ctrls['aadhaar']!,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                color: T.dangerBg,
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: T.danger, size: 16),
                  const SizedBox(width: 8),
                  Text(_error!, style: const TextStyle(color: T.danger,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],

            const SizedBox(height: 28),
            const SizedBox(height: 2, child: ColoredBox(color: T.navy)),
            const SizedBox(height: 20),

            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _GhostButton(label: 'CANCEL',
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              _HardButton(
                label: _saving ? 'SAVING...' : 'SAVE CUSTOMER',
                onTap: _saving ? null : _submit,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DELETE DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _DeleteDialog extends StatefulWidget {
  final String displayId;
  final int customerId;
  final Future<void> Function() onConfirm;

  const _DeleteDialog({
    required this.displayId,
    required this.customerId,
    required this.onConfirm,
  });

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Delete failed.'),
          backgroundColor: T.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.navy, width: 3),
          boxShadow: const [
            BoxShadow(color: T.danger, offset: Offset(12, 12), blurRadius: 0)
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('DELETE CUSTOMER',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                      color: T.navy)),
              _IconBtn(icon: Icons.close, color: T.muted,
                  onTap: () => Navigator.of(context).pop()),
            ]),
            const SizedBox(height: 4),
            const SizedBox(height: 2, child: ColoredBox(color: T.navy)),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, color: T.muted, height: 1.6),
                children: [
                  const TextSpan(text: 'Permanently delete '),
                  // OPT-1: displayId pre-built in _RowData — passed directly
                  TextSpan(text: widget.displayId,
                      style: const TextStyle(fontWeight: FontWeight.w800,
                          color: T.navy)),
                  const TextSpan(text: '? All associated data will be removed. This '),
                  const TextSpan(text: 'cannot be undone.',
                      style: TextStyle(fontWeight: FontWeight.w700, color: T.danger)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(height: 2, child: ColoredBox(color: T.navy)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _GhostButton(label: 'CANCEL',
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              _HardButton(
                label: _deleting ? 'DELETING...' : 'DELETE',
                color: T.danger,
                onTap: _deleting ? null : _confirm,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY / SKELETON STATES
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline, size: 48, color: T.faint),
        SizedBox(height: 16),
        Text('No customer records found.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: T.navy)),
        SizedBox(height: 8),
        Text('Try a different search term.',
            style: TextStyle(color: T.muted)),
      ]),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (_, i) => Container(
        height: 56,
        color: i.isEven ? T.surface : const Color(0xFFFAFAFA),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(children: [
            for (final w in [80.0, 140.0, 100.0, 120.0, 140.0, 60.0]) ...[
              _Skeleton(width: w),
              const SizedBox(width: 16),
            ],
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE LEAF WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _TH extends StatelessWidget {
  final String text;
  final int flex;
  const _TH(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text, style: T.labelStyle),
  );
}

class _Skeleton extends StatelessWidget {
  final double width;
  const _Skeleton({required this.width});

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: 14,
    // BONUS FIX: const BorderRadius — no allocation on every skeleton frame
    decoration: const BoxDecoration(
      color: T.borderL,
      borderRadius: BorderRadius.all(Radius.circular(2)),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      // OPT-3: flat card — no shadow; search field rebuilds on every keystroke
      decoration: T.flatCard,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
            color: T.navy),
        decoration: const InputDecoration(
          hintText: 'Search by name or mobile...',
          hintStyle: TextStyle(color: T.faint, fontWeight: FontWeight.w400),
          prefixIcon: Icon(Icons.search_rounded, color: T.faint, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: T.labelStyle),
      const SizedBox(height: 8),
      Container(
        // OPT-3: flat card — no shadow; form fields rebuild on every character
        decoration: T.flatCard,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 15, color: T.navy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: T.faint),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ]);
  }
}

// ─── Buttons ──────────────────────────────────────────────────────────────────
// OPT-3: Shadow removed from AnimatedContainer — the translate(2,2) already
//        communicates the press state without a GPU offscreen pass.

class _HardButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;

  const _HardButton({
    required this.label,
    this.onTap,
    this.icon,
    this.color = T.primary,
  });

  @override
  State<_HardButton> createState() => _HardButtonState();
}

class _HardButtonState extends State<_HardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown:  disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp:    disabled ? null : (_) { setState(() => _pressed = false); widget.onTap!(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed
            ? (Matrix4.identity()..translate(2.0, 2.0))
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        // OPT-3: No BoxShadow in AnimatedContainer — rebuilds on every press tick
        decoration: BoxDecoration(
          color: disabled ? T.faint : widget.color,
          border: Border.all(color: T.navy, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
          ],
          Text(widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  (_) => setState(() => _pressed = true),
      onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed
            ? (Matrix4.identity()..translate(1.0, 1.0))
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        // OPT-3: No BoxShadow — translate alone signals the press
        decoration: const BoxDecoration(
          color: T.surface,
          border: Border.fromBorderSide(BorderSide(color: T.navy, width: 2)),
        ),
        child: Text(widget.label,
            style: const TextStyle(color: T.navy, fontSize: 13,
                fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color? hoverBg;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon, required this.color,
    required this.onTap, this.hoverBg,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(8),
          // OPT-3: No BoxShadow in AnimatedContainer — rebuilds on hover
          decoration: BoxDecoration(
            color: _hovered && widget.hoverBg != null
                ? widget.hoverBg
                : T.surface,
            border: Border.all(
              color: _hovered ? widget.color : T.borderL,
              width: 1,
            ),
          ),
          child: Icon(widget.icon, size: 16, color: widget.color),
        ),
      ),
    );
  }
}