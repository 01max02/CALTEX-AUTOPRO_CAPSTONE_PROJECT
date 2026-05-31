import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminSmartReports extends StatefulWidget {
  const AdminSmartReports({super.key});

  @override
  State<AdminSmartReports> createState() => _AdminSmartReportsState();
}

class _AdminSmartReportsState extends State<AdminSmartReports> {
  static const _red = Color(0xFFE8001C);
  static const _blue = Color(0xFF003087);

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];

  // Live data loaded from Firestore
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _services = [];
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('vehicles').get(),
      FirebaseFirestore.instance.collection('stock_inventory').get(),
      FirebaseFirestore.instance.collection('maintenance')
          .orderBy('createdAt', descending: true).limit(100).get(),
    ]);

    final now = DateTime.now();

    _assets = results[0].docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      final lastSvcDate = data['lastSvcDate'] as String? ?? '';
      final svcFreq = data['svcFreq'] as String? ?? '';
      final lastDate = DateTime.tryParse(lastSvcDate);
      final months = int.tryParse(svcFreq);
      String nextPMS = '';
      if (lastDate != null && months != null) {
        final next = DateTime(lastDate.year, lastDate.month + months, lastDate.day);
        nextPMS = next.toIso8601String();
      }
      return {
        'plate': data['plate'] as String? ?? '',
        'desc': data['desc'] as String? ?? '',
        'owner': data['owner'] as String? ?? '',
        'status': (data['status'] as String? ?? 'active').toLowerCase(),
        'nextPMS': nextPMS,
      };
    }).toList();

    _inventory = results[1].docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'num': data['num'] as String? ?? '',
        'name': data['name'] as String? ?? '',
        'stock': (data['stock'] as num?)?.toInt() ?? 0,
        'min': (data['min'] as num?)?.toInt() ?? 0,
        'unit': data['uom'] as String? ?? '',
      };
    }).toList();

    _services = results[2].docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      final costStr = (data['cost'] as String? ?? '0').replaceAll('₱', '').replaceAll(',', '');
      return {
        'plate': data['plate'] as String? ?? '',
        'desc': data['desc'] as String? ?? '',
        'cost': double.tryParse(costStr) ?? 0.0,
        'status': data['status'] as String? ?? '',
      };
    }).toList();

    if (mounted) setState(() => _dataLoaded = true);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _sendQuery([String? preset]) {
    final text = preset ?? _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (!_dataLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading data, please wait...'), duration: Duration(seconds: 1)));
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _inputCtrl.clear();
    });
    _scrollToBottom();

    // Detect export intent
    final tl = text.toLowerCase();
    final wantPdf   = tl.contains('pdf') || (tl.contains('generate') && tl.contains('report') && !tl.contains('excel') && !tl.contains('csv'));
    final wantCsv   = tl.contains('excel') || tl.contains('csv') || tl.contains('spreadsheet');
    final wantExport = wantPdf || wantCsv || tl.contains('export') || tl.contains('download') || tl.contains('generate report');

    // Strip export keywords to get the actual data query
    final dataQuery = text
        .replaceAll(RegExp(r'generate\s+(a\s+)?report\s*(for|of|about|on)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'export\s+(to\s+)?(pdf|excel|csv|spreadsheet)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'download\s+(as\s+)?(pdf|excel|csv)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(pdf|excel|csv|spreadsheet)\b', caseSensitive: false), '')
        .trim();

    Future.delayed(const Duration(milliseconds: 600), () async {
      final result = _processQuery(dataQuery.isEmpty ? text : dataQuery);

      if (wantExport && result.rows.isNotEmpty) {
        setState(() => _messages.add(_ChatMessage(
          role: 'ai',
          result: _QueryResult(
            type: 'success', icon: wantCsv ? '📊' : '📄',
            title: wantCsv ? 'Generating CSV Report…' : 'Generating PDF Report…',
            body: 'Preparing "${result.title}" — please wait.',
            rows: [],
          ),
        )));
        _scrollToBottom();

        if (wantCsv) {
          await _exportCsv(result);
        } else {
          await _exportPdf(result);
        }
      } else if (wantExport && result.rows.isEmpty) {
        setState(() => _messages.add(_ChatMessage(
          role: 'ai',
          result: _QueryResult(
            type: 'warning', icon: '⚠️',
            title: 'No Data to Export',
            body: 'No records found for that query. Try a more specific question first.',
            rows: [],
          ),
        )));
        _scrollToBottom();
      } else {
        setState(() => _messages.add(_ChatMessage(role: 'ai', result: result)));
        _scrollToBottom();
      }
    });
  }

  Future<void> _exportPdf(_QueryResult result) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.red, width: 2))),
          child: pw.Row(children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Caltex AutoPro', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
              pw.Text('Smart Reports AI — Generated Report', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 16),
        pw.Text(result.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Generated: $dateStr  ·  ${result.rows.length} record(s)',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        pw.SizedBox(height: 12),
        pw.Text(result.body, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (result.rows.isNotEmpty)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(7),
                    child: pw.Text('Item', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))),
                  pw.Padding(padding: const pw.EdgeInsets.all(7),
                    child: pw.Text('Value', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))),
                ],
              ),
              ...result.rows.asMap().entries.map((e) => pw.TableRow(
                decoration: pw.BoxDecoration(color: e.key.isEven ? PdfColors.grey100 : PdfColors.white),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(e.value.label, style: pw.TextStyle(fontSize: 10, fontWeight: e.value.isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(e.value.value, style: pw.TextStyle(fontSize: 10, fontWeight: e.value.isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
                ],
              )),
            ],
          ),
        pw.SizedBox(height: 24),
        pw.Text('Caltex AutoPro · JA Noble Enterprise INC · Confidential',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      ],
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${result.title.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').replaceAll(' ', '_')}_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.pdf',
    );
  }

  Future<void> _exportCsv(_QueryResult result) async {
    final now = DateTime.now();
    final lines = <String>['Item,Value'];
    for (final row in result.rows) {
      final label = '"${row.label.replaceAll('"', '""')}"';
      final value = '"${row.value.replaceAll('"', '""')}"';
      lines.add('$label,$value');
    }
    lines.add('');
    lines.add('"Generated by Caltex AutoPro Smart Reports AI","${now.day}/${now.month}/${now.year}"');

    final csv = lines.join('\r\n');
    final bytes = csv.codeUnits;

    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: '${result.title.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').replaceAll(' ', '_')}_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.csv',
    );
  }

  _QueryResult _processQuery(String query) {
    final q = query.toLowerCase();

    // Under maintenance
    if (q.contains('under maintenance') || (q.contains('currently') && q.contains('maintenance'))) {
      final list = _assets.where((a) =>
        (a['status'] as String).toLowerCase().contains('maintenance')).toList();
      if (list.isEmpty) return _QueryResult(type: 'success', icon: '✅', title: 'Assets Under Maintenance', body: 'No assets are currently under maintenance.', rows: []);
      return _QueryResult(type: 'blue', icon: '🔵', title: 'Assets Under Maintenance',
        body: '${list.length} asset(s) are currently under maintenance.',
        rows: list.map((a) => _Row(label: '${a['plate']} – ${a['desc']}', value: a['owner'] as String)).toList());
    }

    // PMS overdue
    if (q.contains('overdue') || q.contains('past due') || q.contains('missed')) {
      final now = DateTime.now();
      final list = _assets.where((a) {
        final due = DateTime.tryParse(a['nextPMS'] as String? ?? '');
        return due != null && due.isBefore(now);
      }).toList();
      if (list.isEmpty) return _QueryResult(type: 'success', icon: '✅', title: 'PMS Overdue', body: 'No assets are overdue for PMS.', rows: []);
      return _QueryResult(type: 'danger', icon: '⚠️', title: 'Assets with PMS Overdue',
        body: '${list.length} asset(s) have overdue PMS schedules.',
        rows: list.map((a) {
          final due = DateTime.parse(a['nextPMS'] as String);
          final days = now.difference(due).inDays;
          return _Row(label: '${a['plate']} – ${a['desc']}', value: 'Overdue by $days day(s)');
        }).toList());
    }

    // PMS due soon
    if (q.contains('due soon') || q.contains('upcoming') || (q.contains('pms') && q.contains('schedule'))) {
      final now = DateTime.now();
      final list = _assets.where((a) {
        final due = DateTime.tryParse(a['nextPMS'] as String? ?? '');
        if (due == null) return false;
        final diff = due.difference(now).inDays;
        return diff >= 0 && diff <= 30;
      }).toList();
      if (list.isEmpty) return _QueryResult(type: 'success', icon: '✅', title: 'PMS Due Soon', body: 'No assets have PMS due in the next 30 days.', rows: []);
      return _QueryResult(type: 'warning', icon: '📅', title: 'Assets with PMS Due Soon',
        body: '${list.length} asset(s) have PMS due within 30 days.',
        rows: list.map((a) {
          final due = DateTime.parse(a['nextPMS'] as String);
          final diff = due.difference(now).inDays;
          return _Row(label: '${a['plate']} – ${a['desc']}', value: diff == 0 ? 'Due today!' : 'Due in $diff day(s)');
        }).toList());
    }

    // Low stock
    if (q.contains('low stock') || q.contains('reorder') || q.contains('running low') || q.contains('low in stock')) {
      final list = _inventory.where((i) => (i['stock'] as int) <= (i['min'] as int)).toList();
      if (list.isEmpty) return _QueryResult(type: 'success', icon: '✅', title: 'Low Stock Items', body: 'All inventory items are sufficiently stocked.', rows: []);
      return _QueryResult(type: 'warning', icon: '📦', title: 'Low Stock Inventory Items',
        body: '${list.length} item(s) are at or below minimum stock level.',
        rows: list.map((i) => _Row(label: '${i['num']} – ${i['name']}', value: '${i['stock']} ${i['unit']} (min: ${i['min']})')).toList());
    }

    // Total cost / monthly cost
    if (q.contains('cost') || q.contains('expense') || q.contains('repair cost') || q.contains('monthly')) {
      final total = _services.fold<double>(0, (sum, s) => sum + (s['cost'] as double));
      return _QueryResult(type: 'blue', icon: '💰', title: 'Total Repair Cost',
        body: 'Total maintenance cost across all service transactions.',
        rows: [
          ..._services.map((s) => _Row(label: '${s['plate']} – ${s['desc']}', value: '₱${(s['cost'] as double).toStringAsFixed(2)}')),
          _Row(label: 'TOTAL', value: '₱${total.toStringAsFixed(2)}', isBold: true),
        ]);
    }

    // Asset list
    if ((q.contains('list') && (q.contains('asset') || q.contains('vehicle'))) || q.contains('all vehicle') || q.contains('fleet')) {
      return _QueryResult(type: 'blue', icon: '🚗', title: 'All Vehicles',
        body: '${_assets.length} vehicle(s) registered in the system.',
        rows: _assets.map((a) => _Row(label: '${a['plate']} – ${a['desc']}', value: a['owner'] as String)).toList());
    }

    // Inventory status
    if (q.contains('inventory') || q.contains('stock status') || q.contains('parts')) {
      return _QueryResult(type: 'blue', icon: '📦', title: 'Inventory Status',
        body: '${_inventory.length} item(s) in inventory.',
        rows: _inventory.map((i) => _Row(
          label: '${i['num']} – ${i['name']}',
          value: '${i['stock']} ${i['unit']}',
          isWarning: (i['stock'] as int) <= (i['min'] as int),
        )).toList());
    }

    // Frequently maintained
    if (q.contains('frequent') || q.contains('most maintained') || q.contains('often')) {
      return _QueryResult(type: 'warning', icon: '🔧', title: 'Frequently Maintained Assets',
        body: 'Based on service history, these assets have the most maintenance records.',
        rows: _services.map((s) => _Row(label: '${s['plate']} – ${s['desc']}', value: s['status'] as String)).toList());
    }

    // Default
    return _QueryResult(type: 'info', icon: '🤖', title: 'No Results Found',
      body: 'I couldn\'t understand your query. Try asking about:\n• Low stock items\n• PMS overdue assets\n• Total repair cost\n• Assets under maintenance',
      rows: []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Smart Reports',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Clear chat',
              onPressed: () => setState(() => _messages.clear()),
            ),
        ],
      ),
      body: Column(children: [
        // Chat area
        Expanded(
          child: !_dataLoaded
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading fleet data...', style: TextStyle(color: Color(0xFF718096), fontSize: 13)),
              ]))
            : _messages.isEmpty ? _buildWelcome() : ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (_, i) => _buildBubble(_messages[i]),
          ),
        ),
        // Input bar
        SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendQuery(),
                decoration: InputDecoration(
                  hintText: 'Ask something about your fleet...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF718096)),
                  filled: true, fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendQuery,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _red, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildWelcome() {
    final chips = [
      ('🔧 Frequently maintained assets', 'Which assets are frequently under maintenance?'),
      ('📦 Low stock items', 'What items are low in stock?'),
      ('💰 Repair cost this month', 'Total repair cost this month'),
      ('⚠️ PMS overdue assets', 'Assets with PMS overdue'),
      ('🔵 Under maintenance', 'Which assets are under maintenance?'),
      ('📋 All vehicles', 'List all vehicles'),
      ('📄 PDF: PMS Overdue', 'Generate PDF report for PMS overdue assets'),
      ('📊 CSV: Low Stock', 'Export CSV for low stock items'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.smart_toy_outlined, color: _blue, size: 32),
        ),
        const SizedBox(height: 14),
        const Text('Smart Reports AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1a202c))),
        const SizedBox(height: 6),
        const Text('Ask me anything about your fleet — assets, inventory, maintenance costs, and more. Say "generate PDF report for…" or "export CSV for…" to download a report.',
          style: TextStyle(fontSize: 13, color: Color(0xFF718096)), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: chips.map((c) => GestureDetector(
            onTap: () => _sendQuery(c.$2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFe2e8f0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
              ),
              child: Text(c.$1, style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568), fontWeight: FontWeight.w500)),
            ),
          )).toList(),
        ),
      ]),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    if (msg.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(18)),
          child: Text(msg.text!, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      );
    }

    final r = msg.result!;
    final headerColor = r.type == 'danger' ? _red
        : r.type == 'warning' ? Colors.orange
        : r.type == 'success' ? const Color(0xFF2c7a7b)
        : _blue;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Text(r.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.body, style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568))),
              if (r.rows.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...r.rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(row.label,
                      style: TextStyle(fontSize: 12, fontWeight: row.isBold ? FontWeight.bold : FontWeight.w500,
                        color: const Color(0xFF1a202c)))),
                    Text(row.value,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: row.isBold ? headerColor : row.isWarning ? Colors.orange : headerColor)),
                  ]),
                )),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String? text;
  final _QueryResult? result;
  _ChatMessage({required this.role, this.text, this.result});
}

class _QueryResult {
  final String type, icon, title, body;
  final List<_Row> rows;
  _QueryResult({required this.type, required this.icon, required this.title, required this.body, required this.rows});
}

class _Row {
  final String label, value;
  final bool isBold, isWarning;
  _Row({required this.label, required this.value, this.isBold = false, this.isWarning = false});
}
