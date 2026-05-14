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
        id: nextId,
        name: fields['name']!,
        city: fields['city']!,
        mobile: fields['mobile']!,
        aadhaar: fields['aadhaar']!,
        points: 0,
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
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _maskAadhaar(String a) {
    if (a.length < 4) return a;
    return 'xxxx xxxx ${a.substring(a.length - 4)}';
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
      builder: (_) => _CustomerFormDialog(
        onSave: (fields) async {
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customers',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage your client directory and records',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or mobile...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
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
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Customer', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.people_outline, size: 40, color: Colors.grey),
        const SizedBox(height: 12),
        const Text(
          'No customers found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 4),
        Text(
          _search.isNotEmpty ? 'Try a different search term.' : 'Add your first customer.',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ]),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9),
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(children: const [
            _TH('ID', flex: 2),
            _TH('Name', flex: 3),
            _TH('City', flex: 2),
            _TH('Mobile', flex: 3),
            _TH('Aadhaar', flex: 3),
            _TH('Points', flex: 2),
            _TH('', flex: 1),
          ]),
        ),
        // Rows
        Expanded(
          child: ListView.separated(
            itemCount: _filtered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
            itemBuilder: (_, i) => _CustomerRow(
              customer: _filtered[i],
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

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final VoidCallback onDelete;
  final String Function(String) maskAadhaar;

  const _CustomerRow({
    required this.customer,
    required this.onDelete,
    required this.maskAadhaar,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        // ID
        Expanded(
          flex: 2,
          child: Text(
            '#${c.id}',
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: Color(0xFF555555),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Name
        Expanded(
          flex: 3,
          child: Text(
            c.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // City
        Expanded(
          flex: 2,
          child: Text(
            c.city,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Mobile
        Expanded(
          flex: 3,
          child: Text(
            c.mobile,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Aadhaar masked
        Expanded(
          flex: 3,
          child: Text(
            maskAadhaar(c.aadhaar),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Points
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.points > 0
                  ? Colors.green.shade50
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: c.points > 0
                    ? Colors.green.shade300
                    : const Color(0xFFDDDDDD),
              ),
            ),
            child: Text(
              '${c.points}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.points > 0 ? Colors.green.shade700 : Colors.grey,
              ),
            ),
          ),
        ),
        // Delete btn
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: onDelete,
              tooltip: 'Delete',
              splashRadius: 18,
            ),
          ),
        ),
      ]),
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
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _mobileCtrl.dispose();
    _aadhaarCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name    = _nameCtrl.text.trim();
    final city    = _cityCtrl.text.trim();
    final mobile  = _mobileCtrl.text.trim();
    final aadhaar = _aadhaarCtrl.text.trim();

    if (name.isEmpty)
      return setState(() => _error = 'Name is required');
    if (city.isEmpty)
      return setState(() => _error = 'City is required');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile))
      return setState(() => _error = 'Enter a valid 10-digit mobile number');
    if (!RegExp(r'^\d{12}$').hasMatch(aadhaar))
      return setState(() => _error = 'Enter a valid 12-digit Aadhaar number');

    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave({
        'name': name, 'city': city, 'mobile': mobile, 'aadhaar': aadhaar,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() { _saving = false; _error = 'Request failed. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text(
                  'Add New Customer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 16,
                ),
              ]),
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 16),

              // Fields
              _SimpleField(label: 'Full Name', hint: 'e.g. Jane Doe', controller: _nameCtrl),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _SimpleField(
                  label: 'City', hint: 'e.g. Hyderabad', controller: _cityCtrl,
                )),
                const SizedBox(width: 12),
                Expanded(child: _SimpleField(
                  label: 'Mobile', hint: '10-digit number',
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                )),
              ]),
              const SizedBox(height: 14),
              _SimpleField(
                label: 'Aadhaar', hint: '12-digit number',
                controller: _aadhaarCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Actions
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save Customer'),
                ),
              ]),
            ],
          ),
        ),
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
          content: Text('Delete failed. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Delete Customer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      content: Text(
        'Are you sure you want to delete customer #${widget.customer.id} '
        '(${widget.customer.name})? This action cannot be undone.',
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _deleting ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(_deleting ? 'Deleting...' : 'Delete'),
        ),
      ],
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
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF555555),
        letterSpacing: 0.3,
      ),
    ),
  );
}

class _SimpleField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _SimpleField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
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
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    ]);
  }
}