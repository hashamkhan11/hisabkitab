/*import 'package:flutter/material.dart';
import 'package:hisabkitab/Models/select_category.dart';


class SharedScreenPrompt extends StatelessWidget {
  final String contactId;
  final String contactName;
  final String sharedUserId;
  final String senderName;
  final String senderEmail;
  final String senderMobileNo;
  final String senderImageUrl;

  const SharedScreenPrompt({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.sharedUserId,
    required this.senderName,
     required this.senderEmail,
      required this.senderMobileNo,
     required this.senderImageUrl, 
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ledger from $senderName'),
      content: const Text('Do you want to open this screen in your app?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Decline'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChooseCategoryPage(
                  contactId: contactId,
                  contactName: contactName,
                  sharedUserId: sharedUserId,
                  senderName: senderName,
                 senderEmail: senderEmail,
                 senderMobileNo: senderMobileNo,
                 senderImageUrl: senderImageUrl,
                ),
              ),
            );
          },
          child: const Text('Accept'),
        ),
      ],
    );
  }
}*/
