// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/ai/data/repositories/personalized_explanation_repository.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';
import 'package:smart_med/features/ai/presentation/pages/ai_medication_explanation_page.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/presentation/pages/add_medication_page.dart';
import 'package:smart_med/features/medications/presentation/pages/edit_medication_page.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  MedicationRepository get _medicationRepository => medicationRepository;

  Future<Map<String, MedicationBadgeItem>>? _badgesFuture;
  String _lastMedicationSignature = '';

  Future<void> deleteMedication(
    BuildContext context,
    MedicationRecord medication,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final medicationId = medication.id;

    if (user == null || medicationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete this medication')),
      );
      return;
    }

    try {
      await NotificationService.cancelNotifications(medication.notificationIds);
      await _medicationRepository.deleteMedication(
        uid: user.uid,
        medicationId: medicationId,
      );

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
    MedicationRecord medication,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Medication'),
          content: Text('Are you sure you want to delete ${medication.name}?'),
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
      await deleteMedication(context, medication);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }

    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, MedicationBadgeItem>> _loadBadgesFor(
    List<MedicationRecord> medications,
  ) async {
    if (medications.isEmpty) {
      return const <String, MedicationBadgeItem>{};
    }

    final response = await personalizedExplanationRepository
        .generateExplanation(
          medicationIds: medications
              .map((item) => item.id)
              .whereType<String>()
              .toList(growable: false),
        );
    return {
      for (final badge in response.medicationBadges) badge.medicationId: badge,
    };
  }

  Future<Map<String, MedicationBadgeItem>> _badgeFutureFor(
    List<MedicationRecord> medications,
  ) {
    final signature = medications.map((item) => item.id ?? item.name).join('|');
    if (_badgesFuture != null && signature == _lastMedicationSignature) {
      return _badgesFuture!;
    }

    _lastMedicationSignature = signature;
    _badgesFuture = _loadBadgesFor(medications);
    return _badgesFuture!;
  }

  Future<void> _openAiGuide(MedicationRecord medication) async {
    final medicationId = medication.id;
    if (medicationId == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AiMedicationExplanationPage(medicationIds: [medicationId]),
      ),
    );
  }

  Color _badgeColor(BuildContext context, String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'major':
      case 'severe':
        return Colors.red.shade700;
      case 'moderate':
        return Colors.orange.shade700;
      case 'low':
        return Colors.green.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildMedicationBadge(
    BuildContext context,
    MedicationBadgeItem? badge,
  ) {
    if (badge == null) {
      return const SizedBox.shrink();
    }

    final color = _badgeColor(context, badge.severity);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _handleMedicationAction(
    String action,
    MedicationRecord medication,
  ) async {
    switch (action) {
      case 'explain':
      case 'risks':
        await _openAiGuide(medication);
        break;
      default:
        break;
    }
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

  Widget _buildMedicationThumbnail(
    BuildContext context,
    MedicationRecord medication,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = medication.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 56,
        height: 56,
        color: colorScheme.secondaryContainer,
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.medication,
                    color: colorScheme.onSecondaryContainer,
                    size: 28,
                  );
                },
              )
            : Icon(
                Icons.medication,
                color: colorScheme.onSecondaryContainer,
                size: 28,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medications'), centerTitle: true),
        body: const Center(child: Text('No logged in user found')),
      );
    }

    final medicationsStream = _medicationRepository.watchMedicationRecords(
      uid: user.uid,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Medications'), centerTitle: true),
      body: StreamBuilder<List<MedicationRecord>>(
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

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.medication_outlined, size: 70),
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

          final medications = snapshot.data!;

          return FutureBuilder<Map<String, MedicationBadgeItem>>(
            future: _badgeFutureFor(medications),
            builder: (context, badgeSnapshot) {
              final badgesById =
                  badgeSnapshot.data ?? const <String, MedicationBadgeItem>{};

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: medications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final medication = medications[index];
                  final startDate = _formatDate(medication.startDate);
                  final badge = medication.id == null
                      ? null
                      : badgesById[medication.id];

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
                              _buildMedicationThumbnail(context, medication),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medication.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildMedicationBadge(context, badge),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  _handleMedicationAction(value, medication);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'explain',
                                    child: Text('Explain simply'),
                                  ),
                                  PopupMenuItem(
                                    value: 'risks',
                                    child: Text('Check my risks'),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditMedicationPage(
                                        medication: medication,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () {
                                  confirmDelete(context, medication);
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (medication.dosage.isNotEmpty)
                            buildMedicationInfo(
                              context,
                              'Dosage',
                              medication.dosage,
                            ),
                          if (medication.frequency.isNotEmpty)
                            buildMedicationInfo(
                              context,
                              'Frequency',
                              medication.frequency,
                            ),
                          if (medication.reminderTimes.isNotEmpty)
                            buildMedicationInfo(
                              context,
                              'Reminder times',
                              medication.reminderTimes.join(', '),
                            ),
                          if (startDate.isNotEmpty)
                            buildMedicationInfo(
                              context,
                              'Start Date',
                              startDate,
                            ),
                          if ((medication.notes ?? '').isNotEmpty)
                            buildMedicationInfo(
                              context,
                              'Notes',
                              medication.notes!,
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
}
