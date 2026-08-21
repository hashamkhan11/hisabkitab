import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../repositories/user_repository.dart';

class PaymentService {
  static Future<void> handlePay(BuildContext context, Map<String, dynamic> txn) async {
    // Show Bottom Sheet and wait for user's selection
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choose Payment Method",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text("Easypaisa"),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop("easypaisa");
                },
              ),

              ListTile(
                leading: const Icon(Icons.mobile_friendly),
                title: const Text("JazzCash"),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop("jazzcash");
                },
              ),
            ],
          ),
        );
      },
    );

    //  After bottom sheet closes
    if (result == "jazzcash") {
      payViaJazzCash(context, txn);
    } else if (result == "easypaisa") {
      payViaEasypaisa(context, txn);
    } else {
    }
  }

  static void payViaJazzCash(BuildContext context, Map<String, dynamic> txn) async {
    final amount = txn['credit'];
    final orderRef = "T${DateTime.now().millisecondsSinceEpoch}";

    final me = await UserRepository.getMe();
    final email = me?['email'];
    final mobileNo = me?['mobile_no'];

    if (email == null || email.isEmpty || mobileNo == null || mobileNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your email or mobile number is missing.")),
      );
      return;
    }
    final uri = Uri.parse('https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/jazzcash/generateJazzCashLink');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "amount": (amount * 100).toInt().toString(),
          "orderRef": orderRef,
          "email": email,
          "mobileNo": mobileNo,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final paymentUrl = data['paymentUrl'];

        if (await canLaunchUrl(Uri.parse(paymentUrl))) {
          await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch JazzCash payment page")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("JazzCash request failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  static void payViaEasypaisa(BuildContext context, Map<String, dynamic> txn) async {
    final amount = txn['credit'];
    final orderRef = "EP${DateTime.now().millisecondsSinceEpoch}";

    final me = await UserRepository.getMe();
    final email = me?['email'];
    final mobileNo = me?['mobile_no'];

    if (email == null || email.isEmpty || mobileNo == null || mobileNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your email or mobile number is missing.")),
      );
      return;
    }

    final uri = Uri.parse('https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/easypaisa/generateEasypaisaLink');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "amount": amount.toString(),
          "orderRef": orderRef,
          "email": email,
          "mobileNo": mobileNo,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final paymentUrl = data['paymentUrl'];

        if (await canLaunchUrl(Uri.parse(paymentUrl))) {
          await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch Easypaisa payment page")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Easypaisa request failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  static void showCustomAmountDialog(BuildContext context) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Enter Amount"),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "Enter amount in PKR",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final enteredAmount = amountController.text.trim();
                if (enteredAmount.isEmpty || double.tryParse(enteredAmount) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid amount")),
                  );
                  return;
                }

                final txn = {
                  'credit': double.parse(enteredAmount),
                  'type': 'Custom',
                };
                Navigator.pop(dialogContext);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  handlePay(context, txn);
                });
              },
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }

  // Zero call sites anywhere in the app — carried over unwired (Phase 2 cleanup).
  static Future<void> verifyJazzCashTxn(String txnRefNo) async {
    final url = Uri.parse('https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/inquiry');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'orderRef': txnRefNo}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final inquiryData = data['response'];

      if (inquiryData['pp_ResponseCode'] == '000') {
        //  Payment Successful
      } else if (inquiryData['pp_ResponseCode'] == '124') {
        //  Payment Failed
      } else {
        //  Pending or unknown
      }
    } else {
    }
  }
}
