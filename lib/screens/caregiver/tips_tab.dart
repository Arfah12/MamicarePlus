import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === WARNA TEMA BIRU-PUTIH ===
// === WARNA TEMA BIRU-PUTIH ===
const Color primaryColor = Color(0xFF007BFF);
const Color secondaryColor = Color(0xFF5CB3FF);
const Color cardColor = Colors.white;
const Color backgroundColor = Color(0xFFF5F7FA);
const Color neutralColor = Colors.grey;


// 💡 MODEL DATA
class Tip {
  final String id;
  final String title;
  final String content;
  final String category;

  Tip({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
  });

  factory Tip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tip(
      id: doc.id,
      title: data['title'] ?? 'Tiada Tajuk',
      content: data['content'] ?? 'Tiada kandungan disediakan.',
      category: data['category'] ?? 'Umum',
    );
  }
}

// 📖 WIDGET UTAMA
class TipsTab extends StatefulWidget {
  const TipsTab({super.key});

  @override
  State<TipsTab> createState() => _TipsTabState();
}

class _TipsTabState extends State<TipsTab> {
  final CollectionReference tipsCollection =
      FirebaseFirestore.instance.collection('tips');

  String? _selectedCategory; // Null = Semua
  final List<String> _categories = [
    'Semua',
    'Penjagaan',
    'Gaya Hidup',
    'Komunikasi',
    'Kebersihan Mulut',
    'Perkembangan & Pembelajaran',
    'Pemakanan',
    'Pergigian',
    'Keselamatan',
    'Lain-lain',
  ];

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('kesihatan')) return Icons.local_hospital_rounded;
    if (lower.contains('pemakanan')) return Icons.lunch_dining_rounded;
    if (lower.contains('tidur')) return Icons.bed_rounded;
    if (lower.contains('emosi') || lower.contains('sosial')) return Icons.emoji_people_rounded;
    if (lower.contains('belajar') || lower.contains('kognitif')) return Icons.lightbulb_outline_rounded;
    return Icons.star_border_rounded;
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showTipDialog(BuildContext context, Tip tip, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip.title,
                style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                "Kategori: ${tip.category}",
                style: textTheme.labelLarge?.copyWith(
                    color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const Divider(height: 20, thickness: 1),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    tip.content,
                    style: textTheme.bodyMedium?.copyWith(
                        color: Colors.black87, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("TUTUP",
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  List<Tip> _filterTips(List<Tip> allTips) {
    if (_selectedCategory == null || _selectedCategory == 'Semua') return allTips;

    final selectedLower = _selectedCategory!.toLowerCase();

    return allTips.where((tip) {
      final tipLower = tip.category.toLowerCase();

      if (selectedLower == 'perkembangan & pembelajaran' &&
          (tipLower.contains('perkembangan') || tipLower.contains('pembelajaran'))) {
        return true;
      }

      return tipLower.contains(selectedLower);
    }).toList();
  }

  Widget _buildHeaderTips(TextTheme textTheme, int totalTips) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Tips Keibubapaan',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: primaryColor,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, color: primaryColor, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      totalTips.toString(),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  'Jumlah Tips',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;

  return Scaffold(
    backgroundColor: backgroundColor,
    body: Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/wallpaper1.jpg"),
          fit: BoxFit.cover,
          opacity: 0.9, // lembut
        ),
      ),
        child: StreamBuilder<QuerySnapshot>(
          stream: tipsCollection.orderBy('title').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryColor));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_off_rounded, color: neutralColor, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Tiada tips keibubapaan buat masa ini.',
                      style: textTheme.titleMedium?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            final allTips = snapshot.data!.docs.map((doc) => Tip.fromFirestore(doc)).toList();
            final filteredTips = _filterTips(allTips);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTips(textTheme, allTips.length),

                /// CATEGORY FILTER
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected =
                          category == _selectedCategory || (category == 'Semua' && _selectedCategory == null);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category == 'Semua' ? null : category;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : cardColor,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: isSelected ? primaryColor : neutralColor.withOpacity(0.5)),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : primaryColor,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                /// TIPS LIST
                Expanded(
                  child: filteredTips.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, color: neutralColor, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'Tiada tips untuk kategori "${_selectedCategory}".',
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(color: Colors.black54),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          itemCount: filteredTips.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tip = filteredTips[index];

                            return _VibrantCard(
                              tip: tip,
                              icon: _getCategoryIcon(tip.category),
                              textTheme: textTheme,
                              onTap: () {
                                _showSnackBar(context, "Membuka tip: ${tip.title}");
                                _showTipDialog(context, tip, textTheme);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
  );  
}
}
class _VibrantCard extends StatelessWidget {
  final Tip tip;
  final IconData icon;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _VibrantCard({
    required this.tip,
    required this.icon,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: neutralColor.withOpacity(0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: primaryColor, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(
                      tip.category,
                      style: const TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: secondaryColor.withOpacity(0.2),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.title,
                    style: textTheme.titleLarge?.copyWith(
                        color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.content,
                    style: textTheme.bodyMedium?.copyWith(color: Colors.black54, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 10),
              child: Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
