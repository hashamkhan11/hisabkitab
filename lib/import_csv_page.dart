import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hisabshare/services/notification_service.dart';

class ImportCsvPage extends StatefulWidget {
  final String contactName;

  const ImportCsvPage({super.key, required this.contactName});

  @override
  State<ImportCsvPage> createState() => _ImportCsvPageState();
}

class _ImportCsvPageState extends State<ImportCsvPage> {
  String statusMessage = "No file selected yet.";
  List<List<dynamic>> csvData = [];

  Future<void> _importCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        if (fields.length <= 1) {
          setState(() {
            statusMessage = "CSV file is empty or header-only.";
            csvData = [];
          });
          return;
        }

        // Skip header
        fields.removeAt(0);

        // Store for preview
        setState(() {
          csvData = fields;
        });

        for (var row in fields) {
  if (row.length != 3) continue;

  String dateStr = row[0];
  String originalType = row[1].toString();
  double credit = double.tryParse(row[2].toString()) ?? 0.0;

  String reversedType = originalType == 'Send' ? 'Receive' : 'Send';
  DateTime date = _parseDate(dateStr);

  await FirebaseFirestore.instance
      .collection('contacts')
      .doc(widget.contactName)
      .collection('transactions')
      .add({
    'date': Timestamp.fromDate(date),
    'type': reversedType, 
    'credit': credit,
  });

  // Show local notification for Receive
  if (reversedType == 'Receive') {
    await NotificationService().showNotification(
      title: 'Payment Received',
      body: '₹$credit received from ${widget.contactName}',
    );
  }

  //  Optional: Add Firestore notification too
  await FirebaseFirestore.instance.collection('notifications').add({
    'message': 'Rs$credit received from ${widget.contactName}',
    'timestamp': Timestamp.now(),
    'isRead': false,
  });
}
        setState(() {
          statusMessage = "Transactions imported successfully.";
        });
      } else {
        setState(() {
          statusMessage = "File selection cancelled.";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Error importing CSV: $e";
      });
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      List<String> parts = dateStr.split('/');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      return DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  Widget _buildCsvPreview() {
    if (csvData.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text("CSV Preview:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: csvData.length,
            itemBuilder: (context, index) {
              final row = csvData[index];
              return ListTile(
                title: Text("Date: ${row[0]}, Type: ${row[1]}, Credit: ${row[2]}"),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contacts')
          .doc(widget.contactName)
          .collection('transactions')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error loading transactions.');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text("Imported Transactions:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final date = (data['date'] as Timestamp).toDate();
                  return ListTile(
                    title: Text(
                        "${date.day}/${date.month}/${date.year} - ${data['type']} - Rs${data['credit']}"),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Import CSV - ${widget.contactName}"),
         backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusMessage),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _importCsv,
                icon: const Icon(Icons.upload_file),
                label: const Text("Import CSV"),
              ),
              _buildCsvPreview(),
              _buildTransactionsList(),
            ],
          ),
        ),
      ),
    );
  }
}
