import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:hisabshare/widgets/add_category.dart';
import 'package:hisabshare/screens/detail.dart';
import 'package:hisabshare/models/model.dart';
import 'package:hisabshare/repositories/category_repository.dart';
import 'package:hisabshare/theme/app_theme.dart';

class Categories extends StatelessWidget {
  final List<CategoryModel> categoryList;
  final void Function(CategoryModel) onAddCategory;
  final void Function(CategoryModel) onDeleteCategory;

  const Categories({
    required this.categoryList,
    required this.onAddCategory,
    required this.onDeleteCategory,
    super.key,
  });

  static void openCategory(BuildContext context, CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(
          categoryId: category.id,
          categoryName: category.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: GridView.builder(
        itemCount: categoryList.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final category = categoryList[index];
          return category.isLast
              ? _buildAddCategory(context)
              : _buildCategory(context, category);
        },
      ),
    );
  }

  Widget _buildAddCategory(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () async {
        final newCategory = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (_) => const AddCategorySheet(),
        );
        if (newCategory != null && newCategory is CategoryModel) {
          onAddCategory(newCategory);
        }
      },
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(20),
        dashPattern: const [8, 8],
        color: c.border,
        strokeWidth: 1.6,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: c.accentStrong, size: 28),
              const SizedBox(height: 6),
              Text(
                'Add category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(BuildContext context, CategoryModel category) {
    final c = context.appColors;
    final bg = category.bgColor ?? c.accentSoft;
    final iconColor = category.iconColor ?? c.accentStrong;

    return GestureDetector(
      onTap: () => openCategory(context, category),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete Category'),
            content: Text('Delete "${category.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await CategoryRepository.deleteCategory(category.id);
                  onDeleteCategory(category);
                },
                child: Text('Delete', style: TextStyle(color: c.danger)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(category.iconData ?? Icons.category, color: iconColor, size: 24),
            ),
            const Spacer(),
            Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
