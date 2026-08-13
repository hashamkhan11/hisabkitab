import 'package:flutter/material.dart';
import 'package:hisabshare/models/model.dart';
import 'package:hisabshare/screens/notifications.dart';
import 'package:hisabshare/screens/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/widgets/hisaab.dart';
import 'package:hisabshare/repositories/category_repository.dart';
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
  //num totalsend = 0;
  //num totalreceive = 0;
  int totalSend = 0;
  int totalReceive = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _calculateTotalTransactionsForHome();

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

 /* List<Widget> _pages() => [
        _buildHomeContent(),
        const ProfilePage(),
        const NotificationPage(),
      ];*/
      
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
Future<void> _calculateTotalTransactionsForHome() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  double send = 0.0;
  double receive = 0.0;

  // 1. Your own contacts
  final categories = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories')
      .get();

  for (var categoryDoc in categories.docs) {
    final contacts = await categoryDoc.reference.collection('contacts').get();

    for (var contactDoc in contacts.docs) {
      final txns = await contactDoc.reference.collection('transactions').get();

      for (var doc in txns.docs) {
        final data = doc.data();
        final amount = (data['credit'] ?? 0).toDouble();
        final type = (data['type'] ?? '').toString().toLowerCase();

        if (type == 'send') send += amount;
        else if (type == 'receive') receive += amount;
      }
    }
  }
  // 2. Shared contacts (assuming you store them like this)
  final sharedSnapshot = await FirebaseFirestore.instance
      .collection('shared_contacts')
      .where('sharedWith', isEqualTo: uid)
      .get();

  for (var doc in sharedSnapshot.docs) {
    final contactPath = doc['contactPath']; // example: "users/uid/categories/xyz/contacts/abc"
    final txns = await FirebaseFirestore.instance
        .doc(contactPath)
        .collection('transactions')
        .get();

    for (var txn in txns.docs) {
      final data = txn.data();
      final amount = (data['credit'] ?? 0).toDouble();
      final type = (data['type'] ?? '').toString().toLowerCase();

      if (type == 'send') send += amount;
      else if (type == 'receive') receive += amount;
    }
  }

  setState(() {
    totalSend = send.toInt();
    totalReceive = receive.toInt();
  });
}
Future<void> _refreshData() async {
  setState(() {
    _isLoading = true;
  });
  await _calculateTotalTransactionsForHome();
  setState(() {
    _isLoading = false;
  });
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

   /* _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
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
          ), */

          StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collectionGroup('transactions')
      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    int totalSend = 0;
    int totalReceive = 0;

    for (var doc in snapshot.data!.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = (data['type'] ?? '').toString().toLowerCase();
      final amount = (data['credit'] ?? 0) as num;
      final credit = amount.toInt();

      if (type == 'send') {
        totalSend += credit;
      } else if (type == 'receive') {
        totalReceive += credit;
      }
    }

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

 /*
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

   StreamBuilder<QuerySnapshot>(
 stream: FirebaseFirestore.instance
      .collectionGroup('transactions')
      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
      .snapshots(),
  builder: (context, snapshot) {
    int totalsend = 0;
    int totalreceive = 0;

    if (snapshot.hasData) {
      print(" Total transactions found: ${snapshot.data!.docs.length}");
      for (var doc in snapshot.data!.docs) {
        final data = doc.data() as Map<String, dynamic>;
       // final type = data['type'];
       final type = (data['type'] ?? '').toString().toLowerCase(); 
        final amount = (data['credit'] ?? 0) as num; // 
final credit = (data['credit'] ?? 0) as num;
final int creditInt = credit.toInt();

print(" Transaction => type: $type | credit: $creditInt");
if (type == 'send') {
  totalsend += creditInt;
} else if (type == 'receive') {
  totalreceive += creditInt;
} else {
  print(" Unknown type: $type");
}
      }
      print(" Calculated: send = Rs. $totalsend | Receive = Rs. $totalreceive");
    } else if (snapshot.hasError) {
      print(" Stream error: ${snapshot.error}");
    } else {
      print(" Waiting for data...");
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildBalanceCard(
              title: 'Receive',
              balanceText: 'Rs. $totalreceive',
              color: Colors.green.shade100,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildBalanceCard(
              title: 'Send',
              balanceText: 'Rs. $totalsend',
              color: Colors.red.shade100,
            ),
          ),
        ],
      ),
    );
  },
), 
      Expanded(
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(child: Text("No categories found"));
      }

      final loadedCategories = snapshot.data!.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Category.fromMap(data, doc.id);
      }).toList();

      loadedCategories.add(Category(
        id: 'add_button',
        title: '',
        iconData: Icons.add,
        bgColor: Colors.grey.shade300,
        iconColor: Colors.black,
        isLast: true,
      ));

      return Categories(
        categoryList: loadedCategories,
        onAddCategory: (_) => _navigateToAddCategory(),
        onDeleteCategory:     _deleteCategory,
         
      );
    },
  ),
),
    ],
  ); */
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
