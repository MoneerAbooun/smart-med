// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/edit_medication.dart';
import 'package:smart_med/services/notification_servicce.dart';
import 'add_medication.dart';

class MedicationListPage extends StatelessWidget {
  const MedicationListPage({super.key});

  Future<void> deleteMedication(BuildContext context, String docId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No logged in user found')));
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('medications')
          .doc(docId);

      final docSnapshot = await docRef.get();
      final data = docSnapshot.data();

      final List<dynamic> notificationIds = data?['notificationIds'] is List
          ? List<dynamic>.from(data!['notificationIds'])
          : [];

      await NotificationService.cancelNotifications(notificationIds);

      await docRef.delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication deleted successfully')),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Delete failed')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> confirmDelete(
    BuildContext context,
    String docId,
    String medicationName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Medication'),
          content: Text('Are you sure you want to delete $medicationName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await deleteMedication(context, docId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medications'), centerTitle: true),
        body: const Center(child: Text('No logged in user found')),
      );
    }

    final medicationsStream = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('medications')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Medications'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: medicationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medication_outlined, size: 70),
                    const SizedBox(height: 16),
                    const Text(
                      'No medications added yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap the button below to add your first medication.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddMedicationPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Medication'),
                    ),
                  ],
                ),
              ),
            );
          }

          final medications = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: medications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final medication =
                  medications[index].data() as Map<String, dynamic>;
              final docId = medications[index].id;

              final name = medication['name'] ?? 'Unknown';
              final dose = medication['dose'] ?? 0;
              final doseUnit = medication['doseUnit'] ?? '';
              final frequency = medication['timesPerDay'] ?? 0;
              final times = medication['times'] is List
                  ? List<dynamic>.from(medication['times'])
                  : [];
              final startDate = medication['startDate'] ?? '';
              final note = medication['note'] ?? '';

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.medication,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditMedicationPage(
                                        docId: docId,
                                        name: name.toString(),
                                        dose: dose,
                                        doseUnit:
                                            medication['doseUnit'] ?? 'mg',
                                        timesPerDay:
                                            medication['timesPerDay'] is int
                                            ? medication['timesPerDay']
                                            : int.tryParse(
                                                    medication['timesPerDay']
                                                            ?.toString() ??
                                                        '1',
                                                  ) ??
                                                  1,
                                        times: times,
                                        startDate: startDate.toString(),
                                        note: note.toString(),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () {
                                  confirmDelete(context, docId, name);
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (dose.toString().isNotEmpty)
                        buildMedicationInfo(context, 'Dose', '$dose $doseUnit'),

                      if (frequency.toString().isNotEmpty)
                        buildMedicationInfo(
                          context,
                          'Frequency',
                          '$frequency times per day',
                        ),

                      if (times.isNotEmpty)
                        buildMedicationInfo(
                          context,
                          'Times',
                          times.map((time) => time.toString()).join(', '),
                        ),

                      if (startDate.toString().isNotEmpty)
                        buildMedicationInfo(context, 'Start Date', startDate),

                      if (note.toString().isNotEmpty)
                        buildMedicationInfo(context, 'Note', note),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicationPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget buildMedicationInfo(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
