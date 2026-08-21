import 'package:flutter/material.dart';
import 'package:hisabshare/models/model.dart';
import 'package:hisabshare/screens/notifications.dart';
import 'package:hisabshare/screens/profile.dart';
import 'package:hisabshare/widgets/hisaab.dart';
import 'package:hisabshare/repositories/category_repository.dart';
import 'package:hisabshare/repositories/summary_repository.dart';
import 'package:hisabshare/repositories/user_repository.dart';

class Homepage extends StatefulWidget {
    final void Function(bool) onThemeToggle;
    final bool isDarkMode;
   //  final AppData appData;

    const Homepage({super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
      // required this.appData,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}
class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;
  List<CategoryModel> taskList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  void _addCategory(CategoryModel newCategory) {
  setState(() {
    taskList.insert(taskList.length - 1, newCategory); // before "+Add"
  });
} 

Widget _buildBalanceCard({
  required String title,
  required String balanceText,
  required Color color,
}) {
  return Container(
    height: 90,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 6,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          balanceText,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
}

  Future<void> _loadCategories() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final categories = await CategoryRepository.loadOrInitializeCategories();
    setState(() {
      taskList = categories;
      _isLoading = false;
    });
  } catch (_) {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _deleteCategory(CategoryModel category) {
  if (!category.isLast) {
    setState(() {
      taskList.removeWhere((c) => c.id == category.id);
    });
  }
}

  List<Widget> _pages() => [
  _buildHomeContent(),
  ProfilePage(
    onBackToHome: () {
      setState(() => _selectedIndex = 0); // Switch to homepage tab
    },
  ),
  NotificationPage(
    onBackToHome: () {
      setState(() => _selectedIndex = 0);
    },
  ),
];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
  Widget _buildHomeContent() {

  if (_isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    _buildAppBar(),
    Container(
      padding: const EdgeInsets.all(15),
      child: const Text(
        'Dashboard',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    ),

          StreamBuilder<Map<String, dynamic>>(
  stream: SummaryRepository.balanceStream(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = snapshot.data!;
    final totalReceive = ((data['total_receive'] ?? 0) as num).toInt();
    final totalSend = ((data['total_send'] ?? 0) as num).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildBalanceCard(
              title: 'Receive',
              balanceText: 'Rs. $totalReceive',
              color: Colors.green.shade100,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildBalanceCard(
              title: 'Send',
              balanceText: 'Rs. $totalSend',
              color: Colors.red.shade100,
            ),
          ),
        ],
      ),
    );
  },
),

    Expanded(
      child: taskList.isEmpty
          ? const Center(child: Text("No categories found"))
          : Categories(
              categoryList: taskList,
              onAddCategory: _addCategory,
              onDeleteCategory: _deleteCategory,
            ),
    ),
  ],
);
}
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Color(0xFF89BE4F),
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Text(
        'HisabShare',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
  GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage(onBackToHome: () { Navigator.pop(context); },)),
      );
    },
    child: Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: UserRepository.getMe(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person),
            );
          }

          final imageUrl = snapshot.data!['image_url'];

          return CircleAvatar(
            backgroundImage: imageUrl != null && (imageUrl as String).isNotEmpty
                ? NetworkImage(imageUrl)
                : const AssetImage('assets/logo.png') as ImageProvider,
          );
        },
      ),
    ),
  ),
],
    );
  }
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(211, 211, 211, 0.5),
            spreadRadius: 5,
            blurRadius: 10,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Theme.of(context).unselectedWidgetColor,
          items: const [
            BottomNavigationBarItem(
              label: 'Home',
              icon: Icon(Icons.home_rounded, size: 30),
            ),
            BottomNavigationBarItem(
              label: 'Profile',
              icon: Icon(Icons.person_rounded, size: 30),
            ),
            BottomNavigationBarItem(
              label: 'Notifications',
              icon: Icon(Icons.notifications_active_rounded, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
