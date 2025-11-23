import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'caregiver_details_page.dart';

class ManageCaregiversPage extends StatefulWidget {
  const ManageCaregiversPage({super.key});

  @override
  State<ManageCaregiversPage> createState() => _ManageCaregiversPageState();
}

class _ManageCaregiversPageState extends State<ManageCaregiversPage> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.pink,
        title: const Text(
          "Manage Caregivers",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'SFProText',
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // =========================
          // Search Bar
          // =========================
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: 'Search caregivers',
                prefixIcon: const Icon(Icons.search, color: Colors.pink),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),

          // =========================
          // Caregiver List
          // =========================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'caregiver')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final caregivers = snapshot.data!.docs.where((doc) {
                  final name = doc['name']?.toString().toLowerCase() ?? '';
                  final email = doc['email']?.toString().toLowerCase() ?? '';
                  return name.contains(searchQuery.toLowerCase()) ||
                      email.contains(searchQuery.toLowerCase());
                }).toList();

                if (caregivers.isEmpty) {
                  return const Center(
                    child: Text(
                      "No caregivers found",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: caregivers.length,
                  itemBuilder: (context, index) {
                    final caregiver = caregivers[index];
                    final name = caregiver['name'] ?? 'Unknown';
                    final email = caregiver['email'] ?? '';
                    final joined = caregiver.data().toString().contains('created_at')
                        ? (caregiver['created_at'] as Timestamp)
                            .toDate()
                            .toString()
                            .split(' ')[0]
                        : 'N/A';

                    return Card(
                      elevation: 4,
                      shadowColor: Colors.pink.withOpacity(0.3),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.pink.shade100,
                          child:
                              const Icon(Icons.person, color: Colors.pink, size: 28),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          "$email\nJoined: $joined",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CaregiverDetailsPage(
                                caregiverId: caregiver.id,
                                caregiverName: name,
                                caregiverEmail: email,
                              ),
                            ),
                          );
                        },
                      ),
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
