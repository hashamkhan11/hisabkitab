import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../repositories/statement_email_repository.dart';

class StatementExportService {
  static Future<Uint8List> _buildPdfBytes(
      List<Map<String, dynamic>> transactions, String contactName) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Transactions for $contactName', style: pw.TextStyle(fontSize: 24)),

            pw.SizedBox(height: 20),
            ...transactions.map((tx) {
              final date = tx['date'] as DateTime;

              final type = tx['type'];
              final amount = (tx['credit'] as num).toStringAsFixed(2);
              return pw.Text("${date.day}/${date.month}/${date.year} | $type | Rs$amount");
            }),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndSavePdf(
      BuildContext context, List<Map<String, dynamic>> transactions, contactName) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ No transactions found to export.")),
      );
      return;
    }

    final bytes = await _buildPdfBytes(transactions, contactName);
    final filename = 'transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Emails the same PDF statement [generateAndSavePdf] shares via the OS
  /// share sheet, instead sending it server-side through Resend.
  static Future<void> emailStatement(
    List<Map<String, dynamic>> transactions,
    String contactName,
    String recipientEmail,
  ) async {
    final bytes = await _buildPdfBytes(transactions, contactName);
    final filename = 'transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await StatementEmailRepository.sendStatement(
      recipientEmail: recipientEmail,
      contactName: contactName,
      filename: filename,
      contentBase64: base64Encode(bytes),
    );
  }

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
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Transaction CSV for $contactName'),
    );
  }
}
