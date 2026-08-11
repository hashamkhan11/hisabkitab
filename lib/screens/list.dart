import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ListPage extends StatelessWidget {
  final String categoryName;
  final List<Map<String, dynamic>> contacts;

  const ListPage({
    Key? key,
    required this.categoryName,
    required this.contacts,
  }) : super(key: key);

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Contacts for $categoryName", style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 16),
              ...contacts.map((contact) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Name: ${contact['name'] ?? ''}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("Phone: ${contact['mobileNo'] ?? ''}"),
                  pw.Text("Email: ${contact['email'] ?? ''}"),
                  if (contact['isSharedView'] != true)
                    pw.Text("Address: ${contact['address'] ?? ''}"),
                  pw.SizedBox(height: 12),
                ],
              )),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF89BE4F),
        title: Text(categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Download PDF",
            onPressed: () async {
              final pdfData = await _generatePdf(PdfPageFormat.a4);
              await Printing.sharePdf(bytes: pdfData, filename: '$categoryName-Contacts.pdf');
            },
          ),
        ],
      ),
      body: contacts.isEmpty
          ? const Center(child: Text('No contacts added.'))
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Card(
                  color: index % 2 == 0 ? Colors.orange.shade100 : Colors.deepOrange.shade200,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(
                      contact['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Phone: ${contact['mobileNo'] ?? ''}'),
                        Text('Email: ${contact['email'] ?? ''}'),
                        if (contact['isSharedView'] != true)
                          Text('Address: ${contact['address'] ?? ''}'),
                      ],
                    ),
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Contact'),
                          content: const Text('Are you sure you want to delete this contact?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                contacts.removeAt(index);
                                (context as Element).markNeedsBuild();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contact deleted')),
                                );
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
