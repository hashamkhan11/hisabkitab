import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisabshare/screens/login.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onBackToHome;
  //const ProfilePage({super.key});
  const ProfilePage({required this.onBackToHome, Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  late TextEditingController _nameController;
  late TextEditingController _MobileNoController;
  late TextEditingController _emailController;
  final TextEditingController _NewpasswordController = TextEditingController();
  final TextEditingController _CurrentpasswordController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _MobileNoController = TextEditingController();
    _emailController = TextEditingController(text: user?.email ?? '');
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _imageUrl = data['imageUrl'] as String?;
          _MobileNoController.text = data['mobileNo'] ?? '';
          _nameController.text = data['username'] ?? '';
         // _emailController.text = data['email'] ?? '';
          _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';

        });
      }
    } catch (_) {
    }
  }
}

Future<void> _pickImage(ImageSource source) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User not logged in")),
    );
    return;
  }

  final pickedFile = await _picker.pickImage(source: source, imageQuality: 70); // Optimize upload size

  if (pickedFile != null) {
    try {
      setState(() => _isUploading = true);

      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          //.child('$uid.jpg');
          .child(uid);
   /*  try {
       await ref.delete(); // This will throw error if file doesn't exist
         } catch (e) {
       print("Image deletion skipped: $e");
         }*/

      // Upload the file
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final url = await snapshot.ref.getDownloadURL();

      // Save to Firestore (use merge: true to avoid doc not existing issue)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'imageUrl': url}, SetOptions(merge: true));

        setState(() {
          _imageUrl = url;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile image updated successfully.")),
        );
      } else {
        throw Exception("Upload failed. Try again.");
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }
}
  /*Future<void> _removeImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_imageUrl != null && uid != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');
      await ref.delete();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'imageUrl': FieldValue.delete()});
      setState(() {
        _imageUrl = null;
      });
    }
  }*/
  void _showImageOptions() {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    ),
  );
}
Future<void> sendEmailChangeVerification(String newEmail) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (_) {
    }
  }
}
  Future<void> _saveChanges() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currentUser = FirebaseAuth.instance.currentUser;

    final newName = _nameController.text.trim();
    final newMobileNo = _MobileNoController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPassword = _NewpasswordController.text.trim();
    final currentPassword = _CurrentpasswordController.text.trim();
    bool shouldLogout = false;

  if ((newEmail.isNotEmpty || newPassword.isNotEmpty) && currentPassword.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your current password to proceed.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return; // Stop the function here
  }

  /*  if (newName.isNotEmpty && newName != currentUser?.displayName) {
      await currentUser?.updateDisplayName(newName);
    }*/

    try{
     /* if (newEmail.isNotEmpty) {
        final credential = EmailAuthProvider.credential(
         email: currentUser!.email.toString(),
          password: currentPassword,
        );

        await currentUser.reauthenticateWithCredential(credential);
        await currentUser.verifyBeforeUpdateEmail(newEmail);

        print("changeStarted----------");
        print("current user $currentUser");

         if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email sent. Please check your inbox.'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } 
        shouldLogout = true;
      } */
     if (newEmail.isNotEmpty && newEmail != currentUser!.email) {
  final credential = EmailAuthProvider.credential(
    email: currentUser.email!,
    password: currentPassword,
  );

  await currentUser.reauthenticateWithCredential(credential);
  await currentUser.verifyBeforeUpdateEmail(newEmail);

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email sent. Please check your inbox.'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  shouldLogout = true;
}
    }catch(_){
    }

    if (newPassword.isNotEmpty) {
      await currentUser?.updatePassword(newPassword);
      shouldLogout = true;
      _CurrentpasswordController.clear();
    }

    // Save all fields including name, email, mobileNo directly to users/{uid}
   /* await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'username': newName,
      'mobileNo': newMobileNo,
      'email': newEmail,
      'imageUrl': _imageUrl ?? '',
    }, SetOptions(merge: true)); */// preserve existing imageUrl if unchanged

    Map<String, dynamic> dataToUpdate = {
  'username': newName,
  'mobileNo': newMobileNo,
  'imageUrl': _imageUrl ?? '',
};

//  Only update email in Firestore if it’s actually verified (i.e., not changed or already verified)
if (newEmail == currentUser?.email) {
  dataToUpdate['email'] = newEmail;
}

await FirebaseFirestore.instance.collection('users').doc(uid).set(
  dataToUpdate,
  SetOptions(merge: true),
);

    await currentUser?.reload();

    if (shouldLogout) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your profile has been saved. Log in again.'),
            backgroundColor: Colors.lightGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 3));
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
            backgroundColor: Colors.lightGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}
  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 80,
            backgroundImage: _imageUrl != null
                ? NetworkImage(_imageUrl!)
                : const AssetImage('assets/user.png') as ImageProvider,
            child: _isUploading
                ? const Center(child: CircularProgressIndicator())
                : null,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: InkWell(
              onTap: _showImageOptions,
              child: const CircleAvatar(
                backgroundColor: Colors.teal,
                radius: 20,
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
       Navigator.pushReplacementNamed(
         context, '/Homepage'
         );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: widget.onBackToHome, 
  ),
          title: const Text('Profile'),
          centerTitle: true,
          backgroundColor: Color(0xFF89BE4F),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildProfileImage(),
                const SizedBox(height: 30),
                _buildProfileBox('Username', _nameController),
                const SizedBox(height: 15),
                _buildProfileBox('Mobile No', _MobileNoController),
                const SizedBox(height: 15),
                _buildProfileBox('Email', _emailController),
                const SizedBox(height: 15),
                 _buildProfileBox('New Password', _NewpasswordController, obscure: true),
                const SizedBox(height: 30),
                _buildProfileBox('Current Password', _CurrentpasswordController, obscure: true),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout, color: Colors.black),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF89BE4F), foregroundColor: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBox(String label, TextEditingController controller, {bool obscure = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            spreadRadius: 3,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'Enter your $label',
            ),
          ),
        ],
      ),
    );
  }
}