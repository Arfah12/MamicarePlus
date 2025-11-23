import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageVaccinesPage extends StatefulWidget {
  const ManageVaccinesPage({super.key});

  @override
  State<ManageVaccinesPage> createState() => _ManageVaccinesPageState();
}

class _ManageVaccinesPageState extends State<ManageVaccinesPage> {
  final _nameController = TextEditingController();
  final _monthController = TextEditingController();
  String searchQuery = "";

  void _addVaccine() {
    final name = _nameController.text.trim();
    final month = int.tryParse(_monthController.text.trim());

    if (name.isEmpty || month == null) return;

    FirebaseFirestore.instance.collection('vaccines').add({
      'name': name,
      'month': month,
      'created_at': Timestamp.now(),
    });

    _nameController.clear();
    _monthController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Vaccines"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Vaccine Name', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _monthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Month', border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.pink),
                  onPressed: _addVaccine,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by vaccine name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vaccines')
                  .orderBy('month')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final vaccines = snapshot.data!.docs.where((doc) {
                  final name = doc['name'].toString().toLowerCase();
                  return name.contains(searchQuery.toLowerCase());
                }).toList();

                if (vaccines.isEmpty) return const Center(child: Text("No vaccines found"));

                return ListView.builder(
                  itemCount: vaccines.length,
                  itemBuilder: (context, index) {
                    final vaccine = vaccines[index];
                    return ListTile(
                      title: Text(vaccine['name']),
                      subtitle: Text('Month: ${vaccine['month']}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
