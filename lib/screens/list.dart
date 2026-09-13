import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/contacts_provider.dart';
import '../theme/app_theme.dart';

class ListPage extends StatelessWidget {
  final String categoryName;
  final String categoryId;

  const ListPage({
    required this.categoryName,
    required this.categoryId,
    super.key,
  });

  Future<Uint8List> _generatePdf(PdfPageFormat format, List<Map<String, dynamic>> contacts) async {
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
    final c = context.appColors;
    final contacts = context.watch<ContactsProvider>().contactsFor(categoryId);
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Download PDF",
            onPressed: () async {
              final pdfData = await _generatePdf(PdfPageFormat.a4, contacts);
              await Printing.sharePdf(bytes: pdfData, filename: '$categoryName-Contacts.pdf');
            },
          ),
        ],
      ),
      body: contacts.isEmpty
          ? Center(child: Text('No contacts added.', style: TextStyle(color: c.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Card(
                  color: c.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: c.border),
                  ),
                  child: ListTile(
                    title: Text(
                      contact['name'] ?? '',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.textColor),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Phone: ${contact['mobileNo'] ?? ''}', style: TextStyle(color: c.textMuted)),
                        Text('Email: ${contact['email'] ?? ''}', style: TextStyle(color: c.textMuted)),
                        if (contact['isSharedView'] != true)
                          Text('Address: ${contact['address'] ?? ''}', style: TextStyle(color: c.textMuted)),
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
                              onPressed: () async {
                                Navigator.pop(context);
                                try {
                                  await context.read<ContactsProvider>().deleteContact(categoryId, contact['id'] as String);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Contact deleted')),
                                  );
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to delete contact. Please try again.'),
                                    ),
                                  );
                                }
                              },
                              child: Text('Delete', style: TextStyle(color: c.danger)),
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
