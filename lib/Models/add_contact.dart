import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddContactPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  

  const AddContactPage({Key? key, required this.categoryId, required this.categoryName,}) : super(key: key);

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}
class _AddContactPageState extends State<AddContactPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileNoController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  String? selectedCategory;

  void _submitTask() async {
  if (_formKey.currentState!.validate()) {
    print("📝 Saving contact in categoryId: ${widget.categoryId}, categoryName: ${widget.categoryName}");

    final newContact = {
      'name': nameController.text.trim(),
      'mobileNo': mobileNoController.text.trim(),
      'email': emailController.text.trim(),
      'address': addressController.text.trim(),
      'category': widget.categoryName,
      //'category': selectedCategory,
      ///
      'createdAt': Timestamp.now(),
    };

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final contactDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('categories')
            .doc(widget.categoryId)
           // .doc(selectedCategory)
            .collection('contacts')
           //.doc(nameController.text.trim());
             .doc();

        // Store contact info
        print("📝 Contact data: $newContact");
       await contactDocRef.set(newContact);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact added successfully!')),
        );
      }
      Navigator.pop(context, newContact);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add contact: $e')),
      );
    }
  }
}

  @override
  void dispose() {
    nameController.dispose();
    mobileNoController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: const Text('New Contact'), backgroundColor: Color(0xFF89BE4F), centerTitle: true,),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Contact Name', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter contact name';
                  final nameRegex = RegExp(r'^[a-zA-Z ]+$');
                  if (!nameRegex.hasMatch(val)) return 'Only alphabets allowed';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text('Mobile No', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: mobileNoController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter mobile number';
                  final phoneRegex = RegExp(r'^[0-9]{10,15}$');
                  if (!phoneRegex.hasMatch(val)) return 'Enter valid number (10–15 digits)';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter email';
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(val)) return 'Enter valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Enter address' : null,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _submitTask,
                    child: const Text('Create'),
                    style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF89BE4F), foregroundColor: Colors.black),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
