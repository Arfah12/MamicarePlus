import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// If admin stores Cloudinary URLs, inject optimization transforms after /upload/
String _cloudinaryTransform(String url, {int width = 800}) {
  try {
    if (!url.contains('res.cloudinary.com')) return url;
    final parts = url.split('/upload/');
    if (parts.length != 2) return url;
    return '${parts[0]}/upload/f_auto,q_auto,w_$width/${parts[1]}';
  } catch (_) {
    return url;
  }
}

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
  final String? imageUrl;

  Tip({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.imageUrl,
  });

  factory Tip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tip(
      id: doc.id,
      title: data['title'] ?? 'Tiada Tajuk',
      content: data['content'] ?? 'Tiada kandungan disediakan.',
      category: data['category'] ?? 'Umum',
      imageUrl: data['imageUrl'],
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
    if (lower.contains('emosi') || lower.contains('sosial'))
      return Icons.emoji_people_rounded;
    if (lower.contains('belajar') || lower.contains('kognitif'))
      return Icons.lightbulb_outline_rounded;
    return Icons.star_border_rounded;
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                style: textTheme.labelLarge
                    ?.copyWith(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const Divider(height: 20, thickness: 1),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    tip.content,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: Colors.black87, height: 1.6),
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
    if (_selectedCategory == null || _selectedCategory == 'Semua')
      return allTips;

    final selectedLower = _selectedCategory!.toLowerCase();

    return allTips.where((tip) {
      final tipLower = tip.category.toLowerCase();

      if (selectedLower == 'perkembangan & pembelajaran' &&
          (tipLower.contains('perkembangan') ||
              tipLower.contains('pembelajaran'))) {
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
                    Icon(Icons.lightbulb_rounded,
                        color: primaryColor, size: 20),
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
            image: AssetImage("assets/images/wall13.png"),
            fit: BoxFit.cover,
            opacity: 0.9, // lembut
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: tipsCollection.orderBy('title').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_off_rounded,
                        color: neutralColor, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Tiada tips keibubapaan buat masa ini.',
                      style: textTheme.titleMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            final allTips = snapshot.data!.docs
                .map((doc) => Tip.fromFirestore(doc))
                .toList();
            final filteredTips = _filterTips(allTips);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTips(textTheme, allTips.length),

                /// CATEGORY FILTER
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = category == _selectedCategory ||
                          (category == 'Semua' && _selectedCategory == null);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory =
                                  category == 'Semua' ? null : category;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : cardColor,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : neutralColor.withOpacity(0.5)),
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
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
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
                                Icon(Icons.search_off_rounded,
                                    color: neutralColor, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'Tiada tips untuk kategori "$_selectedCategory".',
                                  textAlign: TextAlign.center,
                                  style: textTheme.titleMedium
                                      ?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                          )
                        : // Cari bahagian ListView.separated di dalam TipsTab dan tukar kepada ini:
                        ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                            itemCount: filteredTips.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final tip = filteredTips[index];

                              return _VibrantCard(
                                tip: tip, // Hantar keseluruhan objek tip
                                textTheme: textTheme,
                                onTap: () {
                                  _showTipDialog(context, tip, textTheme);
                                },
                              );
                            },
                          )),
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
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _VibrantCard({
    required this.tip,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- BAHAGIAN IMEJ URL ---
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: backgroundColor,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: tip.imageUrl != null && tip.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _cloudinaryTransform(tip.imageUrl!),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: neutralColor),
                        ),
                      )
                    : const Icon(Icons.image_rounded, color: neutralColor),
              ),
            ),
            const SizedBox(width: 16),

            // --- BAHAGIAN TEKS ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label Kategori Kecil
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tip.category.toUpperCase(),
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tip.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.content,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: neutralColor),
          ],
        ),
      ),
    );
  }
}
