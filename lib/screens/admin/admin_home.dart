import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  final CollectionReference _vaccinesCollection =
      FirebaseFirestore.instance.collection('vaccines');
  final CollectionReference _milestoneCollection =
      FirebaseFirestore.instance.collection('milestones');
  final CollectionReference _tipsCollection =
      FirebaseFirestore.instance.collection('tips');
  final CollectionReference _caregiversCollection =
      FirebaseFirestore.instance.collection('caregivers');

  static const Color _primaryColor = Color(0xFF673AB7);
  static const Color _accentColor = Color(0xFFFF4081);

  late final List<Widget> _widgetOptions;
  late final List<String> _titles;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      _caregiverTab(),
      _vaccineTab(),
      _milestoneTab(),
      _tipsTab(),
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
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ==================== IMAGE UPLOAD ====================
  Future<String?> _uploadImage(File imageFile, String docId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('tips_images/$docId-${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ralat muat naik imej: $e')));
      return null;
    }
  }

  // ==================== GENERIC CRUD DIALOG ====================
  Future<void> _showCrudDialog({
  required CollectionReference collection,
  required String titlePrefix,
  DocumentSnapshot? doc,
  required List<Map<String, dynamic>> fields,
}) async {
  final Map<String, TextEditingController> controllers = {};
  Map<String, String?> selectedDropdowns = {};
  File? selectedImage;
String? existingImageUrl = (doc?.data() as Map<String, dynamic>?)?['imageUrl'];
bool isTipsTab = collection == _tipsCollection;

  bool showAgeRange = collection != _vaccinesCollection; // Vaksin tak ada julat umur

  // Init controllers & dropdowns
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
          style: const TextStyle(fontWeight: FontWeight.bold),
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
                        child: Image.network(existingImageUrl,
                            height: 100, fit: BoxFit.cover),
                      ),
                    if (selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(selectedImage!,
                            height: 100, fit: BoxFit.cover),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('Pilih Gambar'),
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
                      maxLines: field['key'] == 'description' ||
                              field['key'] == 'content'
                          ? 3
                          : 1,
                      decoration: InputDecoration(
                        labelText: field['label'],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  );
                }
              }).toList(),
              if (showAgeRange) ...[
                const SizedBox(height: 8),
                const Text('Julat Umur (bulan)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageFromController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Dari (bulan)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ageToController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Hingga (bulan)',
                            border: OutlineInputBorder()),
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
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              final data = <String, dynamic>{};
              if (showAgeRange) {
                int from = int.tryParse(ageFromController.text) ?? 0;
                int to = int.tryParse(ageToController.text) ?? 0;
                if (from > to) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Umur "Dari" mesti ≤ "Hingga"')));
                  return;
                }
                data['age_from'] = from;
                data['age_to'] = to;
              }

              for (var field in fields) {
                if (field['type'] == 'dropdown') {
                  data[field['key']] = selectedDropdowns[field['key']];
                } else {
                  data[field['key']] = controllers[field['key']]!.text.trim();
                }
              }

              if (isTipsTab && selectedImage != null) {
                String docId = doc?.id ?? collection.doc().id;
                String? newImageUrl = await _uploadImage(selectedImage!, docId);
                if (newImageUrl != null) data['imageUrl'] = newImageUrl;
              }

              if (doc == null) {
                await collection.add({
                  ...data,
                  'created_at': FieldValue.serverTimestamp()
                });
              } else {
                await collection.doc(doc.id).update(data);
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$titlePrefix disimpan.')));
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _genericDelete(
      CollectionReference collection, String id, String name) async {
    await collection.doc(id).delete();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name dipadam.')));
  }

  // ==================== CAREGIVER TAB ====================
  Widget _caregiverTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _caregiversCollection.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final caregivers = snapshot.data!.docs;
        if (caregivers.isEmpty)
          return const Center(child: Text('Tiada penjaga dijumpai'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: caregivers.length,
          itemBuilder: (context, index) {
            final caregiver = caregivers[index];
            final caregiverData = caregiver.data() as Map<String, dynamic>;

            return Card(
              elevation: 3,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: const Icon(Icons.person_outline, color: _primaryColor),
                title: Text(caregiverData['name'] ?? 'Tiada Nama',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Email: ${caregiverData['email'] ?? ''}\nTel: ${caregiverData['phone'] ?? ''}'),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _caregiversCollection
                        .doc(caregiver.id)
                        .collection('babies')
                        .snapshots(),
                    builder: (context, babySnapshot) {
                      if (!babySnapshot.hasData) return const SizedBox.shrink();
                      final babies = babySnapshot.data!.docs;
                      if (babies.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Tiada bayi berdaftar',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return Column(
                        children: babies.map((baby) {
                          final babyData = baby.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const Icon(Icons.child_care,
                                color: _accentColor),
                            title: Text(babyData['name'] ?? 'Bayi'),
                            subtitle: Text(
                                'Jantina: ${babyData['gender'] ?? ''} | DOB: ${(babyData['dob'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? ''}'),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Padam Penjaga',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () => _genericDelete(
                            _caregiversCollection, caregiver.id, 'Penjaga'),
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

  // ==================== GENERIC TAB BUILDER ====================
  Widget _buildTab(
    CollectionReference collection,
    String title,
    List<Map<String, dynamic>> fields, {
    bool hasCategory = true,
}) {
  return Stack(
    children: [
      StreamBuilder<QuerySnapshot>(
        stream: collection.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text('Tiada $title dijumpai'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ListTile(
                  leading: collection == _tipsCollection
                      ? (data['imageUrl'] != null
                          ? Image.network(data['imageUrl'],
                              width: 40, height: 40, fit: BoxFit.cover)
                          : const Icon(Icons.lightbulb))
                      : const Icon(Icons.article),
                  title: Text(data['name'] ?? data['title'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (collection == _vaccinesCollection)
                        Text('Umur Vaksin: ${data['month'] ?? '-'} bulan'),
                      if (collection != _vaccinesCollection && hasCategory)
                        Text(
                            'Kategori: ${data['category'] ?? '-'}'),
                      if (collection != _vaccinesCollection && data['age_from'] != null)
                        Text('Umur: ${data['age_from']} - ${data['age_to']} bulan'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
  icon: const Icon(Icons.edit, color: Colors.orange),
  onPressed: () async {
    print("Edit button tapped for $title, doc id: ${doc.id}");
    try {
      await _showCrudDialog(
        collection: collection,
        titlePrefix: title,
        doc: doc,
        fields: fields,
      );
      print("Dialog closed successfully for ${doc.id}");
    } catch (e, s) {
      print("Dialog error: $e");
      print(s);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ralat buka dialog: $e')));
    }
  },
),

                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _genericDelete(collection, doc.id, title)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton(
          heroTag: '$title-fab',
          onPressed: () =>
              _showCrudDialog(collection: collection, titlePrefix: title, fields: fields),
          backgroundColor: _accentColor,
          child: const Icon(Icons.add),
        ),
      ),
    ],
  );
}

 Widget _vaccineTab() => _buildTab(_vaccinesCollection, 'Vaksin', [
      {'key': 'name', 'label': 'Nama Vaksin', 'type': 'text'},
      {'key': 'description', 'label': 'Huraian', 'type': 'text'},
      {
        'key': 'month',
        'label': 'Umur Vaksin (bulan)',
        'type': 'dropdown',
        'options': ['0','2','3','4','5','6','9','12']
      },
    ], hasCategory: false);


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
            'Kebersihan Mulut',
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
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Penjaga'),
          BottomNavigationBarItem(icon: Icon(Icons.vaccines), label: 'Vaksin'),
          BottomNavigationBarItem(
              icon: Icon(Icons.track_changes), label: 'Milestone'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Tips'),
        ],
      ),
    );
  }
}
