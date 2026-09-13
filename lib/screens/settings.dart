import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hisabshare/providers/current_user_provider.dart';
import 'package:hisabshare/providers/theme_provider.dart';
import 'package:hisabshare/repositories/user_repository.dart';
import 'package:hisabshare/screens/login.dart';
import 'package:hisabshare/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Settings hub (formerly a single Profile form): a grouped, sectioned
/// layout - header, Account, Preferences, Logout - matching the pattern of
/// modern settings screens rather than one long form.
class SettingsPage extends StatelessWidget {
  final VoidCallback onBackToHome;

  const SettingsPage({required this.onBackToHome, super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final c = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Log out', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBackToHome();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBackToHome),
          title: const Text('Settings'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ProfileHeader(),
            const SizedBox(height: 24),
            _SectionLabel('Account'),
            const SizedBox(height: 8),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                label: 'Change Password',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
                showDivider: false,
              ),
            ]),
            const SizedBox(height: 24),
            _SectionLabel('Preferences'),
            const SizedBox(height: 8),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => _SettingsGroup(children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: Icon(Icons.dark_mode_rounded, color: c.textMuted),
                  title: const Text('Dark Mode'),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.setDarkMode(value),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: Icon(Icons.logout_rounded, color: c.danger),
                label: Text('Logout', style: TextStyle(color: c.danger, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.dangerSoft),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Consumer<CurrentUserProvider>(
      builder: (context, userProvider, _) {
        final imageUrl = userProvider.user?['image_url'] as String?;
        final name = (userProvider.user?['username'] as String?)?.trim();
        final email = FirebaseAuth.instance.currentUser?.email ?? '';
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: c.accentSoft,
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(imageUrl) as ImageProvider
                    : null,
                child: (imageUrl == null || imageUrl.isEmpty)
                    ? Icon(Icons.person_rounded, color: c.accentStrong, size: 30)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (name == null || name.isEmpty) ? 'Your name' : name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: TextStyle(color: c.textMuted, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Text(
      label.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textMuted, letterSpacing: 0.6),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: c.textMuted),
          title: Text(label),
          trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
          onTap: onTap,
        ),
        if (showDivider) Divider(height: 1, color: c.border, indent: 16, endIndent: 16),
      ],
    );
  }
}

/// Avatar + username/mobile/email fields, pushed from [SettingsPage].
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  final TextEditingController _currentPasswordController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _imageUrl;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _mobileController = TextEditingController();
    _emailController = TextEditingController(text: user?.email ?? '');
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await UserRepository.getMe();
      if (data != null && mounted) {
        setState(() {
          _imageUrl = data['image_url'] as String?;
          _mobileController.text = data['mobile_no'] ?? '';
          _nameController.text = data['username'] ?? '';
          _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance.ref().child('profile_images').child(uid);
      final snapshot = await ref.putFile(file);

      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed. Try again.');
      }
      final url = await snapshot.ref.getDownloadURL();
      await UserRepository.updateMe(imageUrl: url);
      if (mounted) context.read<CurrentUserProvider>().refresh();

      setState(() {
        _imageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final newName = _nameController.text.trim();
    final newMobile = _mobileController.text.trim();
    final newEmail = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text.trim();
    final emailChanged = newEmail.isNotEmpty && newEmail != currentUser?.email;

    if (emailChanged && currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your current password to change your email.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      var shouldLogout = false;
      if (emailChanged) {
        final credential = EmailAuthProvider.credential(email: currentUser!.email!, password: currentPassword);
        await currentUser.reauthenticateWithCredential(credential);
        await currentUser.verifyBeforeUpdateEmail(newEmail);
        shouldLogout = true;
      }

      // Email isn't sent here - the backend lazily syncs it from the verified
      // Firebase ID token on every authenticated request, not from client input.
      await UserRepository.updateMe(username: newName, mobileNo: newMobile, imageUrl: _imageUrl ?? '');
      if (mounted) context.read<CurrentUserProvider>().refresh();
      await currentUser?.reload();

      if (!mounted) return;
      if (shouldLogout) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please log in again after confirming.')),
        );
        await Future.delayed(const Duration(seconds: 2));
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final currentUser = FirebaseAuth.instance.currentUser;
    final emailChanged = _emailController.text.trim().isNotEmpty && _emailController.text.trim() != currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: c.accentSoft,
                      backgroundImage: (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(_imageUrl!) as ImageProvider
                          : null,
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : (_imageUrl == null || _imageUrl!.isEmpty)
                              ? Icon(Icons.person_rounded, color: c.accentStrong, size: 48)
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          backgroundColor: c.accentStrong,
                          radius: 18,
                          child: Icon(Icons.camera_alt_rounded, color: c.onAccent, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _field('Username', _nameController),
              const SizedBox(height: 14),
              _field('Mobile No', _mobileController),
              const SizedBox(height: 14),
              _field('Email', _emailController, onChanged: (_) => setState(() {})),
              if (emailChanged) ...[
                const SizedBox(height: 14),
                _field('Current Password', _currentPasswordController, obscure: true),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool obscure = false, void Function(String)? onChanged}) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: 'Enter your $label'),
          ),
        ],
      ),
    );
  }
}

/// Current/new password fields, pushed from [SettingsPage].
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both your current and new password.')),
      );
      return;
    }
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final credential = EmailAuthProvider.credential(email: currentUser!.email!, password: currentPassword);
      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.updatePassword(newPassword);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Please log in again.')),
      );
      await Future.delayed(const Duration(seconds: 2));
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to change password.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change password: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            _field('Current Password', _currentPasswordController, obscure: true),
            const SizedBox(height: 14),
            _field('New Password', _newPasswordController, obscure: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
                      )
                    : const Text('Update password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool obscure = false}) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(hintText: 'Enter your $label'),
          ),
        ],
      ),
    );
  }
}
