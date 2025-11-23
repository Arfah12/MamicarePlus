import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverDetailsPage extends StatelessWidget {
  final String caregiverId;
  final String caregiverName;
  final String caregiverEmail;

  const CaregiverDetailsPage({
    super.key,
    required this.caregiverId,
    required this.caregiverName,
    required this.caregiverEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Caregiver Details"),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // Caregiver Info Card
            // =========================
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.pink.shade100,
                      child: const Icon(Icons.person, color: Colors.pink, size: 35),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(caregiverName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(caregiverEmail,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Assigned Babies",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
            ),
            const SizedBox(height: 10),

            // =========================
            // Babies List
            // =========================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('babies')
                    .where('caregiver_id', isEqualTo: caregiverId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final babies = snapshot.data!.docs;

                  if (babies.isEmpty) {
                    return const Center(
                      child: Text("No babies assigned to this caregiver."),
                    );
                  }

                  return ListView.builder(
                    itemCount: babies.length,
                    itemBuilder: (context, index) {
                      final baby = babies[index];
                      final name = baby['baby_name'] ?? 'Unknown';
                      final gender = baby['gender'] ?? '-';
                      final dob = baby['dob'] != null
                          ? (baby['dob'] as Timestamp)
                              .toDate()
                              .toString()
                              .split(' ')[0]
                          : 'N/A';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.pink.shade100,
                            child: Icon(
                              gender.toLowerCase() == 'female'
                                  ? Icons.female
                                  : Icons.male,
                              color: Colors.pink,
                            ),
                          ),
                          title: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Gender: $gender\nDOB: $dob"),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
