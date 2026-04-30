// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

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

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: int.tryParse(json['CustomerID']?.toString() ?? '0') ?? 0,
      name: json['CustomerName']?.toString() ?? '',
      city: json['CustomerCity']?.toString() ?? '',
      mobile: (json['CustomerMobile']?.toString() ?? '').padLeft(10, '0'),
      aadhaar: json['CustomerAadhaar']?.toString() ?? '',
      points: int.tryParse(json['CustomerPoints']?.toString() ?? '0') ?? 0,
    );
  }

  Customer copyWith({String? name, String? city, String? mobile, String? aadhaar}) {
    return Customer(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      mobile: mobile ?? this.mobile,
      aadhaar: aadhaar ?? this.aadhaar,
      points: points,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────

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

  static BoxDecoration card({double bw = 2, Color? border, Color? bg}) => BoxDecoration(
    color: bg ?? surface,
    border: Border.all(color: border ?? navy, width: bw),
    boxShadow: [BoxShadow(color: navy, offset: const Offset(4, 4), blurRadius: 0)],
  );

  static TextStyle label = const TextStyle(
    fontSize: 11, fontWeight: FontWeight.w800,
    color: navy, letterSpacing: 1.5,
  );
  static TextStyle mono = const TextStyle(
    fontFamily: 'monospace', fontSize: 12,
    fontWeight: FontWeight.w700, color: navy,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMERS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const _api = 'https://petropoints-backend.deploy.splsystems.in/api';

  List<Customer> _customers = [];
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
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _fetchCustomers() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$_api/read'));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() => _customers = data.map((e) => Customer.fromJson(e)).toList());
      } else {
        _toast('Failed to load customers', isError: true);
      }
    } catch (_) {
      _toast('Network error', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addCustomer(Map<String, String> fields) async {
    final nextId = _customers.isEmpty
        ? 7821
        : _customers.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;

    final res = await http.post(
      Uri.parse('$_api/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'id': nextId,
        'name': fields['name'],
        'mobile': fields['mobile'],
        'aadhar': fields['aadhaar'],
        'city': fields['city'],
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      setState(() => _customers.add(Customer(
        id: nextId, name: fields['name']!, city: fields['city']!,
        mobile: fields['mobile']!, aadhaar: fields['aadhaar']!, points: 0,
      )));
      _toast('Customer added');
    } else {
      throw Exception('Failed');
    }
  }

  Future<void> _deleteCustomer(int id) async {
    final res = await http.delete(Uri.parse('$_api/delete/$id'));
    if (res.statusCode == 200) {
      setState(() => _customers.removeWhere((c) => c.id == id));
      _toast('Customer deleted');
    } else {
      throw Exception('Failed');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
      ),
    );
  }

  String _maskAadhaar(String a) {
    if (a.length < 4) return a;
    return '•••• •••• ${a.substring(a.length - 4)}';
  }

  List<Customer> get _filtered {
    final q = _search.toLowerCase();
    final list = q.isEmpty
        ? _customers
        : _customers.where((c) =>
            c.name.toLowerCase().contains(q) || c.mobile.contains(q)).toList();
    return [...list]..sort((a, b) => b.points.compareTo(a.points));
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showAddDialog() {
    showDialog(
      context: context,
      barrierColor: T.navy.withOpacity(0.8),
      builder: (_) => _CustomerFormDialog(
        onSave: (fields) async {
          // Duplicate check
          if (_customers.any((c) => c.mobile == fields['mobile'])) {
            _toast('Mobile number already exists', isError: true);
            return;
          }
          await _addCustomer(fields);
        },
      ),
    );
  }

  void _showDeleteDialog(Customer c) {
    showDialog(
      context: context,
      barrierColor: T.navy.withOpacity(0.8),
      builder: (_) => _DeleteDialog(
        customer: c,
        onConfirm: () async => await _deleteCustomer(c.id),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          Container(height: 3, color: T.navy),
          const SizedBox(height: 24),
          // Search + Add row
          Row(children: [
            Expanded(child: _SearchField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
            )),
            const SizedBox(width: 16),
            _HardButton(label: 'ADD CUSTOMER', icon: Icons.add, onTap: _showAddDialog),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
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

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline, size: 48, color: T.faint),
        const SizedBox(height: 16),
        const Text('No customer records found.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: T.navy)),
        const SizedBox(height: 8),
        Text(_search.isNotEmpty ? 'Try a different search term.' : 'Add your first customer.',
            style: const TextStyle(color: T.muted)),
      ]),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      decoration: T.card(),
      child: Column(children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: T.bg,
            border: Border(bottom: BorderSide(color: T.navy, width: 2)),
          ),
          child: Row(children: const [
            _TH('CUST ID', flex: 2),
            _TH('NAME', flex: 3),
            _TH('CITY', flex: 2),
            _TH('MOBILE', flex: 3),
            _TH('AADHAAR', flex: 3),
            _TH('POINTS', flex: 2),
            _TH('', flex: 1),
          ]),
        ),
        // Rows
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _CustomerRow(
              customer: _filtered[i],
              isEven: i.isEven,
              onDelete: () => _showDeleteDialog(_filtered[i]),
              maskAadhaar: _maskAadhaar,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE ROW
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerRow extends StatefulWidget {
  final Customer customer;
  final bool isEven;
  final VoidCallback onDelete;
  final String Function(String) maskAadhaar;

  const _CustomerRow({
    required this.customer,
    required this.isEven,
    required this.onDelete,
    required this.maskAadhaar,
  });

  @override
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _hovered ? T.bg : (widget.isEven ? T.surface : const Color(0xFFFAFAFA)),
          border: const Border(bottom: BorderSide(color: T.borderL, width: 1)),
        ),
        child: Row(children: [
          // ID
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: T.bg, border: Border.all(color: T.borderL)),
            child: Text('#CUST-${c.id}', style: T.mono, overflow: TextOverflow.ellipsis),
          )),
          const SizedBox(width: 12),
          // Name
          Expanded(flex: 3, child: Text(c.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.navy),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // City
          Expanded(flex: 2, child: Text(c.city,
              style: const TextStyle(fontSize: 14, color: T.muted),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // Mobile
          Expanded(flex: 3, child: Text(c.mobile,
              style: const TextStyle(fontSize: 14, color: T.muted),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // Aadhaar masked
          Expanded(flex: 3, child: Text(widget.maskAadhaar(c.aadhaar),
              style: const TextStyle(fontSize: 14, color: T.muted, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          // Points
          Expanded(flex: 2, child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.points > 0 ? T.successB : T.bg,
                border: Border.all(
                  color: c.points > 0 ? T.successT : T.navy,
                  width: 1,
                ),
              ),
              child: Text('${c.points}',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: c.points > 0 ? T.successT : T.navy,
                  )),
            ),
            if (c.points > 100) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: T.primaryL,
                  border: Border.all(color: T.primary, width: 1),
                ),
                child: const Text('TOP',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900,
                      color: T.primaryD, letterSpacing: 1,
                    )),
              ),
            ],
          ])),
          // Delete btn
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

// ─────────────────────────────────────────────────────────────────────────────
// ADD CUSTOMER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerFormDialog extends StatefulWidget {
  final Future<void> Function(Map<String, String>) onSave;
  const _CustomerFormDialog({required this.onSave});

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _nameCtrl    = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _mobileCtrl  = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _cityCtrl.dispose();
    _mobileCtrl.dispose(); _aadhaarCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name    = _nameCtrl.text.trim();
    final city    = _cityCtrl.text.trim();
    final mobile  = _mobileCtrl.text.trim();
    final aadhaar = _aadhaarCtrl.text.trim();

    if (name.isEmpty)   return setState(() => _error = 'Name is required');
    if (city.isEmpty)   return setState(() => _error = 'City is required');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile))
      return setState(() => _error = 'Enter valid 10-digit mobile');
    if (!RegExp(r'^\d{12}$').hasMatch(aadhaar))
      return setState(() => _error = 'Enter valid 12-digit Aadhaar');

    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave({'name': name, 'city': city, 'mobile': mobile, 'aadhaar': aadhaar});
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
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.navy, width: 3),
          boxShadow: const [BoxShadow(color: T.primary, offset: Offset(12, 12), blurRadius: 0)],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ADD NEW CUSTOMER',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: T.navy, letterSpacing: 0.5)),
            _IconBtn(icon: Icons.close, color: T.muted, onTap: () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 4),
          Container(height: 2, color: T.navy),
          const SizedBox(height: 28),

          // Fields
          _FormField(label: 'FULL LEGAL NAME', hint: 'e.g. Jane Doe', controller: _nameCtrl),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _FormField(label: 'CITY', hint: 'e.g. Hyderabad', controller: _cityCtrl)),
            const SizedBox(width: 16),
            Expanded(child: _FormField(
              label: 'MOBILE', hint: '10-digit number',
              controller: _mobileCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            )),
          ]),
          const SizedBox(height: 20),
          _FormField(
            label: 'AADHAAR', hint: '12-digit number',
            controller: _aadhaarCtrl, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              color: T.dangerBg,
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: T.danger, size: 16),
                const SizedBox(width: 8),
                Text(_error!, style: const TextStyle(color: T.danger, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],

          const SizedBox(height: 28),
          Container(height: 2, color: T.navy),
          const SizedBox(height: 20),

          // Actions
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _GhostButton(label: 'CANCEL', onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 12),
            _HardButton(
              label: _saving ? 'SAVING...' : 'SAVE CUSTOMER',
              onTap: _saving ? null : _submit,
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteDialog extends StatefulWidget {
  final Customer customer;
  final Future<void> Function() onConfirm;
  const _DeleteDialog({required this.customer, required this.onConfirm});

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
          boxShadow: const [BoxShadow(color: T.danger, offset: Offset(12, 12), blurRadius: 0)],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('DELETE CUSTOMER',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: T.navy)),
            _IconBtn(icon: Icons.close, color: T.muted, onTap: () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 4),
          Container(height: 2, color: T.navy),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: T.muted, height: 1.6),
              children: [
                const TextSpan(text: 'Are you sure you want to permanently delete '),
                TextSpan(
                  text: '#CUST-${widget.customer.id}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: T.navy),
                ),
                const TextSpan(text: '? All associated data will be removed. This '),
                const TextSpan(
                  text: 'cannot be undone.',
                  style: TextStyle(fontWeight: FontWeight.w700, color: T.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(height: 2, color: T.navy),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _GhostButton(label: 'CANCEL', onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 12),
            _HardButton(
              label: _deleting ? 'DELETING...' : 'DELETE',
              color: T.danger,
              onTap: _deleting ? null : _confirm,
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  final int flex;
  const _TH(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: T.navy, letterSpacing: 1.5,
        )),
  );
}

class _Skeleton extends StatelessWidget {
  final double width;
  const _Skeleton({required this.width});

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: 14,
    decoration: BoxDecoration(color: T.borderL, borderRadius: BorderRadius.circular(2)),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.navy, width: 2),
        boxShadow: const [BoxShadow(color: T.navy, offset: Offset(2, 2), blurRadius: 0)],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: T.navy),
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
      Text(label, style: T.label),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.navy, width: 2),
          boxShadow: const [BoxShadow(color: T.navy, offset: Offset(2, 2), blurRadius: 0)],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 15, color: T.navy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: T.faint),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ]);
  }
}

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
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) { setState(() => _pressed = false); widget.onTap!(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed ? (Matrix4.identity()..translate(2.0, 2.0)) : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: disabled ? T.faint : widget.color,
          border: Border.all(color: T.navy, width: 2),
          boxShadow: _pressed || disabled ? [] : const [
            BoxShadow(color: T.navy, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
          ],
          Text(widget.label,
              style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w900, letterSpacing: 1,
              )),
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed ? (Matrix4.identity()..translate(1.0, 1.0)) : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.navy, width: 2),
          boxShadow: _pressed ? [] : const [
            BoxShadow(color: T.navy, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Text(widget.label,
            style: const TextStyle(
              color: T.navy, fontSize: 13,
              fontWeight: FontWeight.w900, letterSpacing: 1,
            )),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color? hoverBg;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap, this.hoverBg});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered && widget.hoverBg != null ? widget.hoverBg : T.surface,
            border: Border.all(
              color: _hovered ? widget.color : T.borderL,
              width: 1,
            ),
            boxShadow: _hovered
                ? [const BoxShadow(color: T.navy, offset: Offset(2, 2), blurRadius: 0)]
                : [],
          ),
          child: Icon(widget.icon, size: 16, color: widget.color),
        ),
      ),
    );
  }
}
