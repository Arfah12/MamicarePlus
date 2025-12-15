import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  // Koleksi Peringkat Atas (Master Data)
  final CollectionReference _vaccinesCollection =
      FirebaseFirestore.instance.collection('vaccines');
  final CollectionReference _tipsCollection =
      FirebaseFirestore.instance.collection('tips');
  final CollectionReference _caregiversCollection =
      FirebaseFirestore.instance.collection('caregivers');
  
  // Koleksi MASTER Milestone (Diandaikan untuk membolehkan CRUD oleh Admin)
  final CollectionReference _milestoneCollection =
      FirebaseFirestore.instance.collection('milestones'); 


  static const Color _primaryColor = Color(0xFF00A294); 
  static const Color _accentColor = Color(0xFFC7007E); 

  late final List<Widget> _widgetOptions;
  late final List<String> _titles;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      _caregiverTab(), // Manage User (Penjaga)
      _vaccineTab(), // Vaksin
      _milestoneTab(), // Perkembangan (Milestone Master)
      _tipsTab(), // Tips
    ];
    _titles = <String>[
      'Manage User',
      'Vaksin',
      'Perkembangan',
      'Tips',
    ];
  }

  Future<void> _logout() async {
    await _auth.signOut();
    // Navigate to login route defined in main.dart
    if (mounted) Navigator.pushReplacementNamed(context, '/login'); 
  }

  Future<String?> _uploadImage(File imageFile, String docId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('tips_images/$docId-${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ralat muat naik imej: $e')));
      }
      return null;
    }
  }

  Future<void> _showCrudDialog({
    required CollectionReference collection, // CollectionReference dijamin
    required String titlePrefix,
    DocumentSnapshot? doc,
    required List<Map<String, dynamic>> fields,
  }) async {
    final Map<String, TextEditingController> controllers = {};
    Map<String, String?> selectedDropdowns = {};
    File? selectedImage;
    String? existingImageUrl = (doc?.data() as Map<String, dynamic>?)?['imageUrl'];
    
    bool isTipsTab = collection == _tipsCollection;
    bool isVaccineTab = collection == _vaccinesCollection;
    bool showAgeRange = !isVaccineTab; // Tunjukkan Julat Umur untuk Tips & Milestone

    for (var field in fields) {
      final key = field['key'];
      if (field['type'] == 'dropdown') {
        selectedDropdowns[key] = doc != null
            ? (doc[key]?.toString() ?? field['options'][0])
            : field['options'][0];
      } else {
        controllers[key] =
            TextEditingController(text: doc?[key]?.toString() ?? '');
      }
    }

    final dataMap = doc?.data() as Map<String, dynamic>? ?? {};
    final ageFromController = TextEditingController(text: dataMap['age_from']?.toString() ?? '');
    final ageToController = TextEditingController(text: dataMap['age_to']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            doc == null ? 'Tambah $titlePrefix' : 'Edit $titlePrefix',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTipsTab)
                  Column(
                    children: [
                      if (existingImageUrl != null && selectedImage == null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: existingImageUrl,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (selectedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            selectedImage!,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.image, color: _primaryColor),
                        label: const Text('Pilih Gambar', style: TextStyle(color: _primaryColor)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(
                              source: ImageSource.gallery, imageQuality: 70);
                          if (pickedFile != null) {
                            setState(() => selectedImage = File(pickedFile.path));
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ...fields.map((field) {
                  if (field['type'] == 'dropdown') {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: DropdownButtonFormField<String>(
                        value: selectedDropdowns[field['key']],
                        decoration: InputDecoration(
                          labelText: field['label'],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: _primaryColor)),
                        ),
                        items: (field['options'] as List<String>)
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedDropdowns[field['key']] = val),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: TextField(
                        controller: controllers[field['key']],
                        keyboardType: field['key'] == 'month' || field['key'] == 'age_from' || field['key'] == 'age_to'
                            ? TextInputType.number
                            : TextInputType.text,
                        maxLines: field['key'] == 'description' ||
                                field['key'] == 'content'
                            ? 3
                            : 1,
                        decoration: InputDecoration(
                          labelText: field['label'],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: _primaryColor)),
                        ),
                      ),
                    );
                  }
                }),
                if (showAgeRange) ...[
                  const SizedBox(height: 8),
                  const Text('Julat Umur (bulan)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageFromController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Dari (bulan)',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _primaryColor))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: ageToController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Hingga (bulan)',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _primaryColor))),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final data = <String, dynamic>{};
                if (showAgeRange) {
                  int from = int.tryParse(ageFromController.text) ?? 0;
                  int to = int.tryParse(ageToController.text) ?? 0;
                  if (from > to) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Umur "Dari" mesti ≤ "Hingga"')));
                    }
                    return;
                  }
                  data['age_from'] = from;
                  data['age_to'] = to;
                }

                for (var field in fields) {
                  if (field['type'] == 'dropdown') {
                    data[field['key']] = selectedDropdowns[field['key']];
                  } else {
                    // Pastikan medan nombor seperti 'month' disimpan sebagai int jika bukan kosong
                    if (field['key'] == 'month' && controllers[field['key']]!.text.isNotEmpty) {
                        data[field['key']] = int.tryParse(controllers[field['key']]!.text.trim()) ?? controllers[field['key']]!.text.trim();
                    } else {
                        data[field['key']] = controllers[field['key']]!.text.trim();
                    }
                  }
                }

                if (isTipsTab && selectedImage != null) {
                  String docId = doc?.id ?? collection.doc().id; 
                  String? newImageUrl = await _uploadImage(selectedImage!, docId);
                  if (newImageUrl != null) data['imageUrl'] = newImageUrl;
                }

                try {
                  if (doc == null) {
                    await collection.add({
                      ...data,
                      'created_at': FieldValue.serverTimestamp()
                    });
                  } else {
                    await collection.doc(doc.id).update(data);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ralat Simpan: $e')));
                  }
                  return;
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$titlePrefix disimpan.')));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _genericDelete(
      CollectionReference collection, String id, String name) async {
    try {
      await collection.doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name dipadam.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ralat padam $name: $e')));
      }
    }
  }

  // ==================== 1. CAREGIVER TAB (PENJAGA) ====================
  Widget _caregiverTab() {
    // Menggunakan StreamBuilder untuk kemas kini masa nyata
    return StreamBuilder<QuerySnapshot>(
      stream: _caregiversCollection.limit(50).snapshots(), 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ralat: Gagal memuatkan penjaga. ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        final caregivers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Tapis keluar Admin
          return data['role'] != 'admin'; 
        }).toList();

        if (caregivers.isEmpty) return const Center(child: Text('Tiada penjaga dijumpai'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: caregivers.length,
          itemBuilder: (context, index) {
            final caregiver = caregivers[index];
            final caregiverData = caregiver.data() as Map<String, dynamic>;
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: const Icon(Icons.person_outline, color: _primaryColor),
                title: Text(caregiverData['name'] ?? 'Tiada Nama',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Email: ${caregiverData['email'] ?? ''}\nTel: ${caregiverData['phone'] ?? ''}'),
                children: [
                  // Subquery untuk mendapatkan bayi
                  FutureBuilder<QuerySnapshot>(
                    future: _caregiversCollection
                        .doc(caregiver.id)
                        .collection('babies')
                        .get(),
                    builder: (context, babySnapshot) {
                      if (babySnapshot.hasError) {
                         return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Ralat memuatkan bayi: ${babySnapshot.error}', style: const TextStyle(color: Colors.red)),
                         );
                      }
                      if (!babySnapshot.hasData) return const SizedBox.shrink();
                      
                      final babies = babySnapshot.data!.docs;
                      if (babies.isEmpty) {
                        return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Tiada bayi berdaftar', style: TextStyle(color: Colors.grey)),
                      );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text('Bayi Berdaftar:', style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
                          ),
                          ...babies.map((baby) {
                            final babyData = baby.data() as Map<String, dynamic>;
                            return ListTile(
                              leading: const Icon(Icons.child_care, color: _accentColor),
                              title: Text(babyData['name'] ?? 'Bayi'),
                              subtitle: Text('Jantina: ${babyData['gender'] ?? ''} | DOB: ${(babyData['dob'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? ''}'),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Padam Penjaga', style: TextStyle(color: Colors.red)),
                        onPressed: () => _genericDelete(_caregiversCollection, caregiver.id, 'Penjaga'),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== GENERIC TAB BUILDER (untuk Koleksi Master) ====================
  Widget _buildTab(
    CollectionReference collection, // CollectionReference dijamin
    String title,
    List<Map<String, dynamic>> fields, {
    bool hasCategory = true,
  }) {
    // Menggunakan FutureBuilder kerana data master tidak berubah terlalu kerap
    final Future<QuerySnapshot> fetchFuture = collection.limit(50).get();

    // CRUD diaktifkan secara lalai untuk semua tab yang menggunakan _buildTab ini
    CollectionReference crudCollection = collection;
    bool canCrud = true; 

    return Stack(
      children: [
        FutureBuilder<QuerySnapshot>(
          future: fetchFuture, 
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Ralat: Gagal memuatkan $title. ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryColor));
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return Center(child: Text('Tiada $title dijumpai'));
            
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: collection == _tipsCollection
                        ? (data['imageUrl'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: data['imageUrl'],
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.lightbulb, color: _primaryColor))
                        : collection == _vaccinesCollection
                            ? const Icon(Icons.vaccines, color: _primaryColor)
                            : const Icon(Icons.track_changes, color: _primaryColor),
                    title: Text(data['name'] ?? data['title'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (collection == _vaccinesCollection)
                          Text('Umur Vaksin: ${data['month'] ?? '-'} bulan'),
                        if (collection != _vaccinesCollection && hasCategory)
                          Text('Kategori: ${data['category'] ?? '-'}'),
                        if (collection != _vaccinesCollection && data['age_from'] != null)
                          Text('Umur: ${data['age_from']} - ${data['age_to']} bulan'),
                      ],
                    ),
                    trailing: canCrud ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: _primaryColor),
                          onPressed: () async {
                            await _showCrudDialog(
                              collection: crudCollection, 
                              titlePrefix: title,
                              doc: doc,
                              fields: fields,
                            );
                          },
                        ),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _genericDelete(crudCollection, doc.id, title)),
                      ],
                    ) : null,
                  ),
                );
              },
            );
          },
        ),
        // FAB (Butang Tambah) diaktifkan untuk Koleksi Master
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: '$title-fab',
            onPressed: () => _showCrudDialog(
              collection: collection, 
              titlePrefix: title, 
              fields: fields
            ),
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // ==================== 2. VAKSIN TAB ====================
  Widget _vaccineTab() => _buildTab(_vaccinesCollection, 'Vaksin', [
    {'key': 'name', 'label': 'Nama Vaksin', 'type': 'text'},
    {'key': 'description', 'label': 'Huraian', 'type': 'text'},
    {
      'key': 'month',
      'label': 'Umur Vaksin (bulan)',
      'type': 'dropdown',
      'options': ['0', '2', '3', '4', '5', '6', '9', '12', '18']
    },
  ], hasCategory: false);

  // ==================== 3. MILESTONE TAB (MASTER COLLECTION) ====================
  Widget _milestoneTab() => _buildTab(_milestoneCollection, 'Milestone', [
    {'key': 'name', 'label': 'Tajuk Milestone', 'type': 'text'},
    {'key': 'description', 'label': 'Huraian', 'type': 'text'},
    {
      'key': 'category',
      'label': 'Kategori',
      'type': 'dropdown',
      'options': ['Sosial', 'Komunikasi', 'Kognitif', 'Pergerakan']
    },
  ]);

  // ==================== 4. TIPS TAB ====================
  Widget _tipsTab() => _buildTab(_tipsCollection, 'Tips', [
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
      ]
    },
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Penjaga'),
          BottomNavigationBarItem(icon: Icon(Icons.vaccines), label: 'Vaksin'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Milestone'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Tips'),
        ],
      ),
    );
  }
}