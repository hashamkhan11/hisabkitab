import 'package:flutter/material.dart';
import 'package:hisabshare/widgets/add_category.dart';
import 'package:hisabshare/models/model.dart';
import 'package:hisabshare/screens/notifications.dart';
import 'package:hisabshare/screens/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/widgets/hisaab.dart';
import 'package:hisabshare/repositories/category_repository.dart';

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
    _loadCategoriesFromFirestore();
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

  Future<void> _loadCategoriesFromFirestore() async {
  setState(() {
    _isLoading = true;
  });

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final userCategoriesCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories');

     final snapshot = await userCategoriesCollection.get();

  if (snapshot.docs.isEmpty) {
    final defaultCategories = CategoryRepository.generateCategories();

    final batch = FirebaseFirestore.instance.batch();
    for (var category in defaultCategories) {
  final docRef = userCategoriesCollection.doc(category.id);
  batch.set(docRef, {
    ...category.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });
}
    await batch.commit();
    await _loadCategoriesFromFirestore(); // recursive reload
    return;
  }

  List<CategoryModel> loadedCategories = snapshot.docs.map((doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel.fromMap(data, doc.id);
  }).toList();

  loadedCategories.add(CategoryModel(
    id: 'add_button',
    title: '',
    iconData: Icons.add,
    bgColor: Colors.grey.shade300,
    iconColor: Colors.black,
    isLast: true,
  ));

  setState(() {
    taskList = loadedCategories;
    _isLoading = false;
  });
}

/*void _handleAddCategory(Category newCategory) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final categoryMap = newCategory.toMap();
    categoryMap['createdAt'] = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .add(categoryMap);
    await _loadCategoriesFromFirestore();
  }

  void _handleDeleteCategory(int index) {
    setState(() {
      taskList.removeAt(index);
    });
  }*/
void _showAddCategorySheet(BuildContext context) async {
  final result = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const AddCategorySheet(),
  );

  if (result == 'success') {
    await _loadCategoriesFromFirestore(); //  Refresh categories
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category created successfully')),
    );
  }
}
  void _navigateToAddCategory() async {
  final result = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const AddCategorySheet(),
  );

  if (result == true) {
    await _loadCategoriesFromFirestore(); 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category created successfully')),
    );
  }
}
  /*void _deleteCategory(int index) async {
    if (index >= 0 && index < taskList.length) {
      final deletedTask = taskList[index];
      if (!deletedTask.isLast) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('categories')
              .doc(deletedTask.id)
              .delete();
        }
        setState(() {
          taskList.removeAt(index);
        });
      }
    }
  }*/
  void _deleteCategory(CategoryModel category) async {
  if (!category.isLast) {
    await CategoryRepository.deleteCategory(category.id);
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
            return CategoryModel.fromMap(data, doc.id);
          }).toList();

          loadedCategories.add(CategoryModel(
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
            onDeleteCategory: _deleteCategory,
          );
        },
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
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get(),
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

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final imageUrl = userData['imageUrl'];

          return CircleAvatar(
            backgroundImage: imageUrl != null
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
