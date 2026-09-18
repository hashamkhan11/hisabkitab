import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/contacts_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/header_icon_button.dart';

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
        centerTitle: false,
        actions: [
          HeaderIconButton(
            icon: Icons.picture_as_pdf_outlined,
            tooltip: "Download PDF",
            onTap: () async {
              final pdfData = await _generatePdf(PdfPageFormat.a4, contacts);
              await Printing.sharePdf(bytes: pdfData, filename: '$categoryName-Contacts.pdf');
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: contacts.isEmpty
          ? Center(child: Text('No contacts added.', style: TextStyle(color: c.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
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
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact['name'] ?? '',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.textColor),
                            ),
                            const SizedBox(height: 6),
                            Text('Phone: ${contact['mobileNo'] ?? ''}', style: TextStyle(color: c.textMuted, fontSize: 13)),
                            Text('Email: ${contact['email'] ?? ''}', style: TextStyle(color: c.textMuted, fontSize: 13)),
                            if (contact['isSharedView'] != true)
                              Text('Address: ${contact['address'] ?? ''}', style: TextStyle(color: c.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
