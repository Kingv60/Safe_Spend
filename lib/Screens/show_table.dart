import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:safe_spend/helper%20and%20module/AppColor.dart';
import '../helper and module/sql_helper.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  final DBHelper dbHelper = DBHelper();
  List<Map<String, dynamic>> bills = [];
  double totalAmount = 0;
  Set<int> selectedRows = {};

  Map<int, bool> editingRows = {}; // billId -> editing
  Map<int, TextEditingController> billControllers = {};
  Map<int, TextEditingController> amountControllers = {};
  bool isEditing = false;

  String sortOrder = "DESC"; // Default sort
  final DateFormat formatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rawData = await dbHelper.getBills();
    final total = await dbHelper.getTotalAmount();
    setState(() {
      bills = List<Map<String, dynamic>>.from(rawData);
      totalAmount = total;
      selectedRows.clear();
      editingRows.clear();
      billControllers.clear();
      amountControllers.clear();
      isEditing = false;
    });
  }

  void _startEditing(int billId, String billName, double amount) {
    setState(() {
      editingRows[billId] = true;
      billControllers[billId] = TextEditingController(text: billName);
      amountControllers[billId] = TextEditingController(text: amount.toString());
      isEditing = true;
    });
  }

  Future<void> _saveEdit(int billId) async {
    final billName = billControllers[billId]?.text ?? '';
    final amount = double.tryParse(amountControllers[billId]?.text ?? '0') ?? 0;

    await dbHelper.updateBill(billId, {'bill': billName, 'amount': amount});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill updated')),
    );
    await _loadData();
  }

  Future<void> _deleteBill(int billId) async {
    await dbHelper.deleteBill(billId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill deleted')),
    );
    await _loadData();
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final parsed = DateTime.tryParse(dateValue.toString());
      if (parsed != null) {
        return formatter.format(parsed);
      }
      // if it's a short string (avoid RangeError)
      final str = dateValue.toString();
      return str.length >= 10 ? str.substring(0, 10) : str;
    } catch (_) {
      return dateValue.toString();
    }
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final headers = ['No.', 'Bill', 'Amount', 'Date'];

    final rows = [
      ...bills.asMap().entries.map((e) => [
        (e.key + 1).toString(),
        e.value['bill'] ?? '',
        e.value['amount'].toString(),
        _formatDate(e.value['date']),
      ]),
      ['', 'Total', totalAmount.toStringAsFixed(2), ''],
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Table.fromTextArray(
          headers: headers,
          data: rows,
          border: pw.TableBorder.all(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ),
    );
    return pdf.save();
  }

  Future<void> _printOrSavePdf() async {
    final bytes = await _buildPdf();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  void _sortBills() {
    setState(() {
      if (sortOrder == "ASC") {
        bills.sort((a, b) => (a['amount'] ?? 0).compareTo(b['amount'] ?? 0));
      } else {
        bills.sort((a, b) => (b['amount'] ?? 0).compareTo(a['amount'] ?? 0));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Records Table"),
        backgroundColor: AppColors.accent,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print / Save PDF',
            onPressed: _printOrSavePdf,
          ),
          if (isEditing) ...[
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save edits',
              onPressed: () {
                for (var entry in editingRows.entries) {
                  if (entry.value) {
                    _saveEdit(entry.key);
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel edits',
              onPressed: () {
                setState(() {
                  editingRows.clear();
                  billControllers.clear();
                  amountControllers.clear();
                  isEditing = false;
                });
              },
            ),
          ],
          DropdownButton<String>(
            value: sortOrder,
            items: const [
              DropdownMenuItem(value: "ASC", child: Text("Amount ↑")),
              DropdownMenuItem(value: "DESC", child: Text("Amount ↓")),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  sortOrder = value;
                  _sortBills();
                });
              }
            },
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => selectedRows.clear()),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 24,
                child: DataTable(
                  headingRowColor:
                  MaterialStateProperty.all(Colors.grey[200]),
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnSpacing: 20,
                  dataRowHeight: 45,
                  headingRowHeight: 50,
                  columns: const [
                    DataColumn(
                        label: Text("No.",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text("Bill",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text("Amount",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text("Date",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    ...bills.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final bill = entry.value;
                      final billId = bill["id"] as int;
                      final isRowEditing = editingRows[billId] ?? false;

                      return DataRow(
                        selected: selectedRows.contains(billId),
                        onLongPress: () {
                          showMenu(
                            context: context,
                            position: const RelativeRect.fromLTRB(100, 100, 0, 0),
                            items: [
                              PopupMenuItem(
                                child: const Text("Edit"),
                                onTap: () => _startEditing(
                                  billId,
                                  bill['bill'] ?? '',
                                  (bill['amount'] ?? 0).toDouble(),
                                ),
                              ),
                              PopupMenuItem(
                                child: const Text("Delete"),
                                onTap: () => _deleteBill(billId),
                              ),
                            ],
                          );
                        },
                        cells: [
                          DataCell(Text(index.toString())),
                          DataCell(
                            isRowEditing
                                ? TextFormField(controller: billControllers[billId])
                                : Text(bill['bill'] ?? ''),
                          ),
                          DataCell(
                            isRowEditing
                                ? TextFormField(
                              controller: amountControllers[billId],
                              keyboardType: TextInputType.number,
                            )
                                : Text("₹${bill['amount']}"),
                          ),
                          DataCell(Text(_formatDate(bill['date']))),
                        ],
                      );
                    }),
                    DataRow(
                      color: MaterialStateProperty.all(Colors.blueGrey[50]),
                      cells: [
                        const DataCell(Text("")),
                        const DataCell(Text("Total",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text("₹${totalAmount.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text("")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
