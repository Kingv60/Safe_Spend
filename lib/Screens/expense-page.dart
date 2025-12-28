import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../helper and module/Api-Service.dart';

enum SortOrder { ascending, descending }

class ExpensesPage extends StatefulWidget {
  final int sharedListId;
  final String sharedListName;
  final String sharecode;

  const ExpensesPage({
    Key? key,
    required this.sharedListId,
    required this.sharedListName,
    required this.sharecode,
  }) : super(key: key);

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> expenses = [];
  double totalAmount = 0;

  Map<int, bool> editingRows = {};
  Map<int, TextEditingController> descControllers = {};
  Map<int, TextEditingController> amountControllers = {};
  bool isEditing = false;

  SortOrder? selectedSort;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  /// Load expenses
  Future<void> _loadExpenses() async {
    try {
      final result =
      await apiService.getSharedExpenses(shareCode: widget.sharecode);
      setState(() {
        expenses = List<Map<String, dynamic>>.from(result);
        totalAmount =
            expenses.fold(0.0, (sum, e) => sum + (e['amount'] ?? 0));
        editingRows.clear();
        descControllers.clear();
        amountControllers.clear();
        isEditing = false;
        _applySorting();
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading expenses: $e')));
    }
  }

  /// Start editing
  void _startEditing(int expenseId, String description, double amount) {
    setState(() {
      editingRows[expenseId] = true;
      descControllers[expenseId] = TextEditingController(text: description);
      amountControllers[expenseId] = TextEditingController(text: amount.toString());
      isEditing = true;
    });
  }

  /// Save edit
  Future<void> _saveEdit(int expenseId, int userId) async {
    try {
      final desc = descControllers[expenseId]?.text ?? '';
      final amt = double.tryParse(amountControllers[expenseId]?.text ?? "0") ?? 0;

      await apiService.updateSharedExpense(
        id: expenseId,
        description: desc,
        amount: amt,
        shareCode: widget.sharecode,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense updated')));
      await _loadExpenses();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  /// Delete expense
  Future<void> _deleteExpense(int expenseId, int userId) async {
    try {
      await apiService.deleteSharedExpense(
        id: expenseId,
        shareCode: widget.sharecode,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense deleted')));
      await _loadExpenses();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  /// Build PDF
  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final headers = ['No.', 'Expense', 'Amount', 'Date'];

    final rows = [
      ...expenses.asMap().entries.map((e) => [
        (e.key + 1).toString(),
        e.value['description'] ?? '',
        e.value['amount'].toString(),
        e.value['createdAt'] != null
            ? e.value['createdAt'].substring(0, 10)
            : '',
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

  /// Print / Save PDF
  Future<void> _printOrSavePdf() async {
    final bytes = await _buildPdf();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Apply sorting
  void _applySorting() {
    if (selectedSort != null) {
      expenses.sort((a, b) {
        final amtA = a['amount'] ?? 0.0;
        final amtB = b['amount'] ?? 0.0;
        return selectedSort == SortOrder.ascending
            ? amtA.compareTo(amtB)
            : amtB.compareTo(amtA);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sharedListName),
        backgroundColor: const Color(0xffB8F8FF),
        actions: [
          IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print / Save PDF',
              onPressed: _printOrSavePdf),
          if (isEditing) ...[
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save edits',
              onPressed: () {
                for (var entry in editingRows.entries) {
                  if (entry.value) {
                    final exp =
                    expenses.firstWhere((e) => e['id'] == entry.key);
                    _saveEdit(entry.key, exp['userId']);
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
                  descControllers.clear();
                  amountControllers.clear();
                  isEditing = false;
                });
              },
            ),
          ],
        ],
      ),
      body: expenses.isEmpty
          ? const Center(child: Text('No expenses found.'))
          : Column(
        children: [
          // Dropdown filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Sort by amount: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<SortOrder>(
                  value: selectedSort,
                  hint: const Text("Select"),
                  items: const [
                    DropdownMenuItem(
                      value: SortOrder.ascending,
                      child: Text("Ascending"),
                    ),
                    DropdownMenuItem(
                      value: SortOrder.descending,
                      child: Text("Descending"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSort = value;
                      _applySorting();
                    });
                  },
                ),
              ],
            ),
          ),
          // DataTable
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 24,
                  child: DataTable(
                    headingRowColor:
                    MaterialStateProperty.all(Colors.grey[200]),
                    border:
                    TableBorder.all(color: Colors.grey.shade300),
                    columnSpacing: 20,
                    dataRowHeight: 45,
                    headingRowHeight: 50,
                    columns: const [
                      DataColumn(
                          label: Text("No.",
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text("Expense",
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text("Amount",
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text("Date",
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      ...expenses.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final expense = entry.value;
                        final expenseId = expense['id'] as int;
                        final isRowEditing = editingRows[expenseId] ?? false;

                        return DataRow(
                          onLongPress: () {
                            showMenu(
                              context: context,
                              position: const RelativeRect.fromLTRB(
                                  100, 100, 0, 0),
                              items: [
                                PopupMenuItem(
                                    child: const Text("Edit"),
                                    onTap: () => _startEditing(
                                        expenseId,
                                        expense['description'],
                                        expense['amount']
                                            .toDouble())),
                                PopupMenuItem(
                                    child: const Text("Delete"),
                                    onTap: () => _deleteExpense(
                                        expenseId, expense['userId'])),
                              ],
                            );
                          },
                          cells: [
                            DataCell(Text(index.toString())),
                            DataCell(isRowEditing
                                ? TextFormField(
                                controller:
                                descControllers[expenseId])
                                : Text(expense['description'] ?? '')),
                            DataCell(isRowEditing
                                ? TextFormField(
                                controller:
                                amountControllers[expenseId],
                                keyboardType:
                                TextInputType.number)
                                : Text(expense['amount'].toString())),
                            DataCell(Text(expense['createdAt']
                                ?.substring(0, 10) ??
                                '')),
                          ],
                        );
                      }),
                      // Total row
                      DataRow(
                        color: MaterialStateProperty.all(
                            Colors.blueGrey[50]),
                        cells: [
                          const DataCell(Text("")),
                          const DataCell(Text("Total",
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(
                              "₹${totalAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          const DataCell(Text("")),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
