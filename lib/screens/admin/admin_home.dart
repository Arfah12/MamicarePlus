import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_login.dart';

// Top-level theme colors (accessible from any widget)
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFF1976D2);
const Color kBgColor = Color(0xFFF7F9FA);

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Firestore collections
  final CollectionReference _vaccinesCollection =
      FirebaseFirestore.instance.collection('vaccines');
  final CollectionReference _tipsCollection =
      FirebaseFirestore.instance.collection('tips');
  final CollectionReference _caregiversCollection =
      FirebaseFirestore.instance.collection('caregivers');
  final CollectionReference _milestoneCollection =
      FirebaseFirestore.instance.collection('milestones');

  // Navigation
  int _selectedIndex = 0;
  late final List<String> _titles;

  // Dialog state cache
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titles = const [
      'Papan Pemuka',
      'Urus Pengguna',
      'Vaksin',
      'Pencapaian',
      'Tips',
    ];
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      );
    }
  }

  Future<String?> _uploadImage(File imageFile, String docId) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
          'tips_images/$docId-${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      _toast('Ralat muat naik imej: $e');
      return null;
    }
  }

  // ----------------------------- CRUD Dialog -----------------------------
  Future<void> _showCrudDialog({
    required CollectionReference collection,
    required String titlePrefix,
    DocumentSnapshot? doc,
    required List<Map<String, dynamic>> fields,
  }) async {
    final Map<String, TextEditingController> controllers = {};
    Map<String, String?> selectedDropdowns = {};
    // will be either a File (mobile) or Uint8List (web bytes)
    dynamic selectedImage;
    String? existingImageUrl =
        (doc?.data() as Map<String, dynamic>?)?['imageUrl'] as String?;

    final isTipsTab = collection == _tipsCollection;
    final isVaccineTab = collection == _vaccinesCollection;
    final showAgeRange = !isVaccineTab;

    // prepare controllers/dropdowns
    for (var field in fields) {
      final key = field['key'] as String;
      final type = field['type'] as String;
      if (type == 'dropdown') {
        final options =
            (field['options'] as List).map((e) => e.toString()).toList();
        selectedDropdowns[key] = doc != null
            ? ((doc.data() as Map<String, dynamic>)[key]?.toString() ??
                options.first)
            : options.first;
      } else {
        controllers[key] = TextEditingController(
          text: (doc?.data() as Map?)?[key]?.toString() ?? '',
        );
      }
    }

    final dataMap = doc?.data() as Map<String, dynamic>? ?? {};
    final ageFromController =
        TextEditingController(text: dataMap['age_from']?.toString() ?? '');
    final ageToController =
        TextEditingController(text: dataMap['age_to']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc == null
                                ? 'Tambah $titlePrefix'
                                : 'Edit $titlePrefix',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tips image section
                    if (isTipsTab)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 86,
                                    height: 86,
                                    child: selectedImage != null
                                        ? (kIsWeb
                                            ? Image.memory(
                                                selectedImage as Uint8List,
                                                fit: BoxFit.cover)
                                            : Image.file(selectedImage as File,
                                                fit: BoxFit.cover))
                                        : (existingImageUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl:
                                                    existingImageUrl ?? '',
                                                height: 100,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.image,
                                                    color: Colors.grey),
                                              )),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Imej Tips',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedImage != null
                                            ? 'Imej dipilih'
                                            : (existingImageUrl != null
                                                ? 'Menggunakan imej sedia ada'
                                                : 'Tiada imej, (pilihan)'),
                                        style: TextStyle(
                                            color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.image,
                                                color: kPrimaryColor),
                                            label: const Text('Pilih Gambar',
                                                style: TextStyle(
                                                    color: kPrimaryColor)),
                                            onPressed: () async {
                                              final pickedFile =
                                                  await _imagePicker.pickImage(
                                                source: ImageSource.gallery,
                                                imageQuality: 78,
                                              );
                                              if (pickedFile != null) {
                                                if (kIsWeb) {
                                                  final bytes = await pickedFile
                                                      .readAsBytes();
                                                  setState(() =>
                                                      selectedImage = bytes);
                                                } else {
                                                  setState(() => selectedImage =
                                                      File(pickedFile.path));
                                                }
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          if (selectedImage != null ||
                                              existingImageUrl != null)
                                            TextButton(
                                              child: const Text('Buang imej',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                              onPressed: () {
                                                setState(() {
                                                  selectedImage = null;
                                                  existingImageUrl = null;
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),

                    // Dynamic fields
                    ...fields.map((field) {
                      final key = field['key'] as String;
                      final type = field['type'] as String;
                      final label = field['label'] as String;
                      if (type == 'dropdown') {
                        final options = (field['options'] as List)
                            .map((e) => e.toString())
                            .toList();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: DropdownButtonFormField<String>(
                            value: selectedDropdowns[key],
                            decoration: _inputDecoration(label),
                            items: options
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => selectedDropdowns[key] = val),
                          ),
                        );
                      } else {
                        final isNumber = key == 'month' ||
                            key == 'age_from' ||
                            key == 'age_to';
                        final maxLines =
                            key == 'description' || key == 'content' ? 3 : 1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: TextFormField(
                            controller: controllers[key],
                            keyboardType: isNumber
                                ? TextInputType.number
                                : TextInputType.text,
                            maxLines: maxLines,
                            decoration: _inputDecoration(label),
                            validator: (val) {
                              if ((val?.trim().isEmpty ?? true) &&
                                  key != 'description' &&
                                  key != 'content') {
                                return 'Medan ini wajib diisi';
                              }
                              return null;
                            },
                          ),
                        );
                      }
                    }),

                    // Age range (for non-vaccine)
                    if (showAgeRange) ...[
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Julat Umur (bulan)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ageFromController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Dari (bulan)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: ageToController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Hingga (bulan)'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: () async {
                              final data = <String, dynamic>{};

                              if (showAgeRange) {
                                final from =
                                    int.tryParse(ageFromController.text.trim());
                                final to =
                                    int.tryParse(ageToController.text.trim());
                                if (from == null || to == null) {
                                  _toast('Sila isi julat umur dengan nombor.');
                                  return;
                                }
                                if (from > to) {
                                  _toast('Umur "Dari" mesti ≤ "Hingga".');
                                  return;
                                }
                                data['age_from'] = from;
                                data['age_to'] = to;
                              }

                              for (var field in fields) {
                                final key = field['key'] as String;
                                final type = field['type'] as String;
                                if (type == 'dropdown') {
                                  data[key] = selectedDropdowns[key];
                                } else {
                                  final text = controllers[key]!.text.trim();
                                  if (key == 'month' && text.isNotEmpty) {
                                    data[key] = int.tryParse(text) ?? text;
                                  } else {
                                    data[key] = text;
                                  }
                                }
                              }

                              if (isTipsTab) {
                                final docId = doc?.id ?? collection.doc().id;
                                final finalImageUrl = await uploadOrUseImage(
                                  imageFile: selectedImage,
                                  imageUrl: existingImageUrl,
                                  docId: docId,
                                );

                                if (finalImageUrl != null) {
                                  data['imageUrl'] = finalImageUrl;
                                } else {
                                  data.remove('imageUrl');
                                }
                              }

                              try {
                                if (doc == null) {
                                  await collection.add({
                                    ...data,
                                    'created_at': FieldValue.serverTimestamp(),
                                  });
                                } else {
                                  await collection.doc(doc.id).update(data);
                                }
                              } catch (e) {
                                _toast('Ralat Simpan: $e');
                                return;
                              }

                              if (mounted) {
                                Navigator.pop(context);
                                _toast('$titlePrefix disimpan.');
                              }
                            },
                            label: const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: kPrimaryColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> uploadOrUseImage({
    dynamic imageFile,
    String? imageUrl,
    required String docId,
  }) async {
    try {
      if (imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
            'tips_images/$docId-${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (kIsWeb && imageFile is Uint8List) {
          // on web, upload bytes
          await ref.putData(
              imageFile, SettableMetadata(contentType: 'image/jpeg'));
        } else if (imageFile is File) {
          await ref.putFile(imageFile);
        } else {
          // unknown type: attempt to upload as bytes if possible
          return imageUrl;
        }
        return await ref.getDownloadURL();
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        return imageUrl;
      } else {
        return null;
      }
    } catch (e) {
      _toast('Ralat muat naik / guna imej: $e');
      return null;
    }
  }

  Future<void> _genericDelete(
      CollectionReference collection, String id, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sahkan Padam'),
        content: Text('Adakah anda pasti mahu memadam "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Padam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await collection.doc(id).delete();
      _toast('$name dipadam.');
    } catch (e) {
      _toast('Ralat padam $name: $e');
    }
  }

  // ----------------------------- Dashboard -----------------------------
  Widget _dashboardTab(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _DashboardHeader(
                title: 'Papan Pemuka Admin',
                subtitle: 'Lihat ringkasan dan urus kandungan',
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Stats cards
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: _caregiversCollection.snapshots(),
                builder: (context, caregiverSnap) {
                  final caregiversCount = (caregiverSnap.data?.docs ?? [])
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['role'] !=
                          'admin')
                      .length;

                  return StreamBuilder<QuerySnapshot>(
                    stream: _vaccinesCollection.snapshots(),
                    builder: (context, vaccineSnap) {
                      final vaccinesCount = vaccineSnap.data?.docs.length ?? 0;

                      return StreamBuilder<QuerySnapshot>(
                        stream: _tipsCollection.snapshots(),
                        builder: (context, tipsSnap) {
                          final tipsCount = tipsSnap.data?.docs.length ?? 0;

                          return StreamBuilder<QuerySnapshot>(
                            stream: _milestoneCollection.snapshots(),
                            builder: (context, milestoneSnap) {
                              final milestoneCount =
                                  milestoneSnap.data?.docs.length ?? 0;

                              final cards = [
                                _StatCardData(
                                  title: 'Penjaga',
                                  value: caregiversCount,
                                  icon: Icons.people,
                                  color1: const Color(0xFFE3F2FD), // Light Blue
                                  color2: const Color(0xFF1565C0), // Dark Blue
                                  tabIndex: 1,
                                ),
                                _StatCardData(
                                  title: 'Vaksin',
                                  value: vaccinesCount,
                                  icon: Icons.vaccines,
                                  color1:
                                      const Color(0xFFFFF3E0), // Light Orange
                                  color2:
                                      const Color(0xFFEF6C00), // Dark Orange
                                  tabIndex: 2,
                                ),
                                _StatCardData(
                                  title: 'Tips',
                                  value: tipsCount,
                                  icon: Icons.lightbulb,
                                  color1:
                                      const Color(0xFFF3E5F5), // Light Purple
                                  color2:
                                      const Color(0xFF7B1FA2), // Dark Purple
                                  tabIndex: 4,
                                ),
                                _StatCardData(
                                  title: 'Milestone',
                                  value: milestoneCount,
                                  icon: Icons.track_changes,
                                  color1: const Color(0xFFE0F2F1), // Light Teal
                                  color2: const Color(0xFF00695C), // Dark Teal
                                  tabIndex: 3,
                                ),
                              ];

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isWide ? 4 : 2,
                                  childAspectRatio: isWide ? 0.75 : 0.85,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: cards.length,
                                itemBuilder: (context, i) {
                                  final data = cards[i];
                                  return _StatCard(
                                    data: data,
                                    onTap: () => setState(
                                        () => _selectedIndex = data.tabIndex),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // ----------------------------- Caregivers -----------------------------
  Widget _caregiverTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _caregiversCollection.limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Ralat: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        final caregivers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] != 'admin';
        }).toList();

        if (caregivers.isEmpty) {
          return const Center(child: Text('Tiada penjaga dijumpai'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: caregivers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final caregiver = caregivers[index];
            final data = caregiver.data() as Map<String, dynamic>;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                  child: const Icon(Icons.person, color: kPrimaryColor),
                ),
                title: Text(
                  data['name'] ?? 'Tiada Nama',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${data['email'] ?? ''}\n${data['phone'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                trailing: const Icon(Icons.expand_more),
                children: [
                  const Divider(),

                  /// ===== BAYI =====
                  FutureBuilder<QuerySnapshot>(
                    future: _caregiversCollection
                        .doc(caregiver.id)
                        .collection('babies')
                        .get(),
                    builder: (context, babySnapshot) {
                      if (!babySnapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        );
                      }

                      final babies = babySnapshot.data!.docs;

                      if (babies.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Tiada bayi berdaftar',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BAYI BERDAFTAR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: kAccentColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...babies.map((baby) {
                            final babyData =
                                baby.data() as Map<String, dynamic>;
                            final dob = (babyData['dob'] as Timestamp?)
                                ?.toDate()
                                .toString()
                                .split(' ')
                                .first;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        kAccentColor.withOpacity(0.1),
                                    child: const Icon(
                                      Icons.child_care,
                                      color: kAccentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          babyData['name'] ?? 'Bayi',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Jantina: ${babyData['gender'] ?? ''} | Tarikh Lahir: ${dob ?? ''}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  /// ===== ACTION =====
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Padam Penjaga',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () => _genericDelete(
                          _caregiversCollection, caregiver.id, 'Penjaga'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------- Generic tab builder -----------------------------
  Widget _buildTab(
    CollectionReference collection,
    String title,
    List<Map<String, dynamic>> fields, {
    bool hasCategory = true,
  }) {
    final future = collection.limit(50).get();
    final canCrud = true;

    return Stack(
      children: [
        FutureBuilder<QuerySnapshot>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child:
                      Text('Ralat: Gagal memuatkan $title. ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: kPrimaryColor));
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Center(child: Text('Tiada $title dijumpai'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final titleText =
                    (data['name'] ?? data['title'] ?? '-').toString();

                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: collection == _tipsCollection
                        ? (data['imageUrl'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: (data['imageUrl'] as String),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const _CircleIcon(
                                icon: Icons.lightbulb, color: kPrimaryColor))
                        : collection == _vaccinesCollection
                            ? const _CircleIcon(
                                icon: Icons.vaccines, color: kPrimaryColor)
                            : const _CircleIcon(
                                icon: Icons.track_changes,
                                color: kPrimaryColor),
                    title: Text(titleText,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (collection == _vaccinesCollection)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                'Umur Vaksin: ${data['month']?.toString() ?? '-'} bulan'),
                          ),
                        if (collection != _vaccinesCollection && hasCategory)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                                'Kategori: ${data['category']?.toString() ?? '-'}'),
                          ),
                        if (collection != _vaccinesCollection &&
                            data['age_from'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                                'Umur: ${data['age_from']} - ${data['age_to']} bulan'),
                          ),
                      ],
                    ),
                    trailing: canCrud
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit,
                                    color: kPrimaryColor),
                                onPressed: () async {
                                  await _showCrudDialog(
                                    collection: collection,
                                    titlePrefix: title,
                                    doc: doc,
                                    fields: fields,
                                  );
                                  setState(() {}); // refresh view
                                },
                              ),
                              IconButton(
                                tooltip: 'Padam',
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _genericDelete(collection, doc.id, title),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: '$title-fab',
            onPressed: () => _showCrudDialog(
              collection: collection,
              titlePrefix: title,
              fields: fields,
            ),
            backgroundColor: kAccentColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Tambah'),
          ),
        ),
      ],
    );
  }

  // ----------------------------- Specific tabs -----------------------------
  Widget _vaccineTab() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _vaccinesCollection.orderBy('month').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Ralat: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              );
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('Tiada data vaksin'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    leading: CircleAvatar(
                      backgroundColor: kPrimaryColor.withOpacity(0.1),
                      child: const Icon(Icons.vaccines, color: kPrimaryColor),
                    ),
                    title: Text(
                      data['name'] ?? 'Vaksin',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Umur: ${data['month']} bulan',
                      style: const TextStyle(fontSize: 13),
                    ),
                    children: [
                      const Divider(),
                      _infoRow('Huraian', data['description'] ?? '-'),
                      const SizedBox(height: 12),

                      /// ACTIONS
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon:
                                  const Icon(Icons.edit, color: kPrimaryColor),
                              label: const Text('Edit'),
                              onPressed: () async {
                                await _showCrudDialog(
                                  collection: _vaccinesCollection,
                                  titlePrefix: 'Vaksin',
                                  doc: doc,
                                  fields: [
                                    {
                                      'key': 'name',
                                      'label': 'Nama Vaksin',
                                      'type': 'text'
                                    },
                                    {
                                      'key': 'description',
                                      'label': 'Huraian',
                                      'type': 'text'
                                    },
                                    {
                                      'key': 'month',
                                      'label': 'Umur (bulan)',
                                      'type': 'dropdown',
                                      'options': [
                                        '0',
                                        '2',
                                        '3',
                                        '4',
                                        '5',
                                        '6',
                                        '9',
                                        '12',
                                        '18'
                                      ],
                                    },
                                  ],
                                );
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              label: const Text('Padam',
                                  style: TextStyle(color: Colors.red)),
                              onPressed: () => _genericDelete(
                                  _vaccinesCollection, doc.id, 'Vaksin'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        /// ===== FLOATING ADD BUTTON =====
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'add-vaccine',
            backgroundColor: kAccentColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Vaksin'),
            onPressed: () => _showCrudDialog(
              collection: _vaccinesCollection,
              titlePrefix: 'Vaksin',
              fields: [
                {'key': 'name', 'label': 'Nama Vaksin', 'type': 'text'},
                {'key': 'description', 'label': 'Huraian', 'type': 'text'},
                {
                  'key': 'month',
                  'label': 'Umur (bulan)',
                  'type': 'dropdown',
                  'options': ['0', '2', '3', '4', '5', '6', '9', '12', '18'],
                },
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _milestoneTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _milestoneCollection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ralat: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor));
        }

        final milestones = snapshot.data!.docs;

        if (milestones.isEmpty) {
          return const Center(child: Text('Tiada milestone dijumpai'));
        }

        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: milestones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                final data = milestone.data() as Map<String, dynamic>;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    leading: const _CircleIcon(
                        icon: Icons.track_changes, color: kPrimaryColor),
                    title: Text(
                      data['name'] ?? '-',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['category'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('Kategori: ${data['category']}'),
                          ),
                        if (data['description'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('${data['description']}'),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.expand_more),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: kPrimaryColor),
                            onPressed: () async {
                              await _showCrudDialog(
                                collection: _milestoneCollection,
                                titlePrefix: 'Milestone',
                                doc: milestone,
                                fields: [
                                  {
                                    'key': 'name',
                                    'label': 'Tajuk Milestone',
                                    'type': 'text'
                                  },
                                  {
                                    'key': 'description',
                                    'label': 'Huraian',
                                    'type': 'text'
                                  },
                                  {
                                    'key': 'category',
                                    'label': 'Kategori',
                                    'type': 'dropdown',
                                    'options': [
                                      'Sosial',
                                      'Komunikasi',
                                      'Kognitif',
                                      'Pergerakan'
                                    ],
                                  },
                                ],
                              );
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _genericDelete(
                                _milestoneCollection,
                                milestone.id,
                                'Milestone'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'milestone-fab',
                onPressed: () => _showCrudDialog(
                  collection: _milestoneCollection,
                  titlePrefix: 'Milestone',
                  fields: [
                    {'key': 'name', 'label': 'Tajuk Milestone', 'type': 'text'},
                    {'key': 'description', 'label': 'Huraian', 'type': 'text'},
                    {
                      'key': 'category',
                      'label': 'Kategori',
                      'type': 'dropdown',
                      'options': [
                        'Sosial',
                        'Komunikasi',
                        'Kognitif',
                        'Pergerakan'
                      ],
                    },
                  ],
                ),
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Milestone'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tipsTab() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _tipsCollection.orderBy('category').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Ralat: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              );
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('Tiada tips direkodkan'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    leading: CircleAvatar(
                      backgroundColor: kPrimaryColor.withOpacity(0.1),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: kPrimaryColor,
                      ),
                    ),
                    title: Text(
                      data['title'] ?? 'Tips',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Kategori: ${data['category'] ?? '-'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    children: [
                      const Divider(),
                      _infoRow('Kandungan', data['content'] ?? '-'),
                      const SizedBox(height: 12),

                      /// ===== ACTION BUTTONS =====
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon:
                                  const Icon(Icons.edit, color: kPrimaryColor),
                              label: const Text('Edit'),
                              onPressed: () {
                                _showCrudDialog(
                                  collection: _tipsCollection,
                                  titlePrefix: 'Tips',
                                  doc: doc,
                                  fields: [
                                    {
                                      'key': 'title',
                                      'label': 'Tajuk Tips',
                                      'type': 'text'
                                    },
                                    {
                                      'key': 'content',
                                      'label': 'Kandungan',
                                      'type': 'text'
                                    },
                                    {
                                      'key': 'category',
                                      'label': 'Kategori',
                                      'type': 'dropdown',
                                      'options': [
                                        'Penjagaan',
                                        'Gaya Hidup',
                                        'Komunikasi',
                                        'Kebersihan Mulut',
                                        'Perkembangan & Pembelajaran',
                                        'Pemakanan',
                                        'Pergigian',
                                        'Keselamatan',
                                        'Lain-lain',
                                      ],
                                    },
                                  ],
                                );
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              label: const Text(
                                'Padam',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () => _genericDelete(
                                _tipsCollection,
                                doc.id,
                                'Tips',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        /// ===== FLOATING ADD TIPS =====
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'add-tips',
            backgroundColor: kAccentColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Tips'),
            onPressed: () {
              _showCrudDialog(
                collection: _tipsCollection,
                titlePrefix: 'Tips',
                fields: [
                  {'key': 'title', 'label': 'Tajuk Tips', 'type': 'text'},
                  {'key': 'content', 'label': 'Kandungan', 'type': 'text'},
                  {
                    'key': 'category',
                    'label': 'Kategori',
                    'type': 'dropdown',
                    'options': [
                      'Penjagaan',
                      'Gaya Hidup',
                      'Komunikasi',
                      'Kebersihan Mulut',
                      'Perkembangan & Pembelajaran',
                      'Pemakanan',
                      'Pergigian',
                      'Keselamatan',
                      'Lain-lain',
                    ],
                  },
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ----------------------------- Scaffold & responsive navigation -----------------------------
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _dashboardTab(context),
      _caregiverTab(),
      _vaccineTab(),
      _milestoneTab(),
      _tipsTab(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        return Scaffold(
          backgroundColor: kBgColor,
          appBar: isWide
              ? null
              : AppBar(
                  title: Text(_titles[_selectedIndex]),
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  actions: [
                    IconButton(
                        icon: const Icon(Icons.logout), onPressed: _logout),
                  ],
                ),
          body: Row(
            children: [
              if (isWide)
                _SideNavRail(
                  selectedIndex: _selectedIndex,
                  onSelect: (i) => setState(() => _selectedIndex = i),
                  onLogout: _logout,
                  titles: _titles,
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: pages[_selectedIndex],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  selectedItemColor: kPrimaryColor,
                  unselectedItemColor: Colors.grey,
                  selectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.bold),
                  type: BottomNavigationBarType.fixed,
                  onTap: (i) => setState(() => _selectedIndex = i),
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard), label: 'Papan Pemuka'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.people), label: 'Penjaga'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.vaccines), label: 'Vaksin'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.track_changes), label: 'Pencapaian'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.lightbulb), label: 'Tips'),
                  ],
                ),
        );
      },
    );
  }
}

// ----------------------------- UI helpers & components -----------------------------

class _DashboardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _DashboardHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Selamat Datang,',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  Text(
                    'Admin MamiCare',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  )
                ],
              ),
            ),
            if (MediaQuery.of(context).size.width > 600)
              Container(
                width: 300,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari sesuatu...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Text('⌘K',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rumusan Papan Pemuka",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Tarikh: ${DateTime.now().toString().split(' ')[0]}",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 18),
              label: const Text("Tapis"),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryColor),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _CircleIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleIcon(icon: icon, color: color),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// Stats card model
class _StatCardData {
  final String title;
  final int value;
  final IconData icon;
  final Color color1;
  final Color color2;
  final int tabIndex;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color1,
    required this.color2,
    required this.tabIndex,
  });
}

// Stats card widget dengan animasi count-up
class _StatCard extends StatelessWidget {
  final _StatCardData data;
  final VoidCallback onTap;

  const _StatCard({
    Key? key,
    required this.data,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: data.color1,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.title,
                    style: TextStyle(
                      color: data.color2,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(Icons.more_horiz, color: data.color2),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.color2, size: 24),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jumlah Rekod',
                  style: TextStyle(
                      color: Colors.black54.withOpacity(0.5), fontSize: 12),
                ),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: data.value),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, _) => Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.65,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation(data.color2),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Side navigation for wide screens
class _SideNavRail extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onSelect;
  final Future<void> Function() onLogout;
  final List<String> titles;

  const _SideNavRail({
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.titles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MamiCare+',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 10, 16, 8),
                  child: Text(
                    "UTAMA",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2),
                  ),
                ),
                _NavItem(
                  label: titles[0],
                  icon: Icons.dashboard_outlined,
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 24, 16, 8),
                  child: Text(
                    "REKOD",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2),
                  ),
                ),
                _NavItem(
                  label: titles[1],
                  icon: Icons.people_outline,
                  selected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
                _NavItem(
                  label: titles[2],
                  icon: Icons.vaccines_outlined,
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _NavItem(
                  label: titles[3],
                  icon: Icons.track_changes_outlined,
                  selected: selectedIndex == 3,
                  onTap: () => onSelect(3),
                ),
                _NavItem(
                  label: titles[4],
                  icon: Icons.lightbulb_outline,
                  selected: selectedIndex == 4,
                  onTap: () => onSelect(4),
                ),
              ],
            ),
          ),

          // Support / Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                InkWell(
                  onTap: onLogout,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 4),
                    child: Row(
                      children: const [
                        Icon(Icons.logout, color: Colors.grey, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Log Keluar',
                          style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Pastel selection color
    final bgColor = selected ? const Color(0xFFE3F2FD) : Colors.transparent;
    final textColor = selected ? const Color(0xFF1565C0) : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.chevron_right,
                    color: Color(0xFF1565C0), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Safe helpers -----------------------------
int? _elementAtOrNull(List<int>? list, int index) {
  if (list == null || index < 0 || index >= list.length) return null;
  return list[index];
}
