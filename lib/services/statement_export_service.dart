import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class StatementExportService {
  static Future<void> generateAndSavePdf(
      BuildContext context, List<Map<String, dynamic>> transactions, contactName) async {
    print(" PDF called with ${transactions.length} transactions");

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ No transactions found to export.")),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Transactions for $contactName', style: pw.TextStyle(fontSize: 24)),

            pw.SizedBox(height: 20),
            ...transactions.map((tx) {
              final rawDate = tx['date'];
              final date = rawDate is Timestamp ? rawDate.toDate() : rawDate as DateTime;

              final type = tx['type'];
              final amount = (tx['credit'] as num).toStringAsFixed(2);
              return pw.Text("${date.day}/${date.month}/${date.year} | $type | Rs$amount");
            }),
          ],
        ),
      ),
    );
    // Request permission
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(" Storage permission denied.")),
      );
      return;
    }
    // Save to Downloads
    final downloadsDir = Directory('/storage/emulated/0/Download');
    final filename = 'transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${downloadsDir.path}/$filename');

    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(" PDF saved to Downloads:\n$filename")),
    );
  }

  // Always exports an empty CSV today — the transactions list it's called
  // with is only ever populated by a method that's never invoked. Moved
  // as-is, still broken (Phase 2 decision — not fixed here).
  static Future<void> shareCsv(
      BuildContext context, List<Map<String, dynamic>> transactions, String contactName) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to share.')),
      );
      return;
    }
    List<List<dynamic>> csvData = [
      ['Date', 'Type', 'Credit'], // Header
      ...transactions.map((txn) => [
            DateFormat('dd/MM/yyyy').format(txn['date']),
            txn['type'],
            txn['credit'].toString(),
          ])
    ];
    String csv = const ListToCsvConverter().convert(csvData);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${contactName}_transactions.csv';
    final file = File(path);
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Transaction CSV for $contactName');
  }
}
