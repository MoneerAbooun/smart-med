import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/core/firebase/image_storage_repository.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/ai/data/repositories/personalized_explanation_repository.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';
import 'package:smart_med/features/medications/presentation/widgets/safety_preview_sheet.dart';

class EditMedicationPage extends StatefulWidget {
  final MedicationRecord medication;

  const EditMedicationPage({super.key, required this.medication});

  @override
  State<EditMedicationPage> createState() => _EditMedicationPageState();
}

class _EditMedicationPageState extends State<EditMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final MedicationRepository _medicationRepository = medicationRepository;
  final PersonalizedExplanationRepository _explanationRepository =
      personalizedExplanationRepository;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageStorageRepository _imageStorageRepository = imageStorageRepository;

  late TextEditingController nameController;
  late TextEditingController doseController;
  late TextEditingController timesPerDayController;
  late TextEditingController startDateController;
  late TextEditingController noteController;

  final List<TextEditingController> timeControllers = [];
  XFile? _selectedMedicationImage;
  Uint8List? _selectedMedicationImageBytes;

  bool isLoading = false;
  int timesPerDay = 1;

  final List<String> doseUnits = ['mg', 'ml', 'tablet', 'capsule'];
  late String selectedDoseUnit;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.medication.name);
    doseController = TextEditingController(
      text: _formatDoseAmount(widget.medication.doseAmount),
    );
    timesPerDayController = TextEditingController(
      text: widget.medication.frequencyPerDay.toString(),
    );
    startDateController = TextEditingController(
      text: _formatDateForInput(widget.medication.startDate),
    );
    noteController = TextEditingController(text: widget.medication.notes ?? '');

    selectedDoseUnit = doseUnits.contains(widget.medication.doseUnit)
        ? widget.medication.doseUnit
        : 'mg';

    _updateTimeControllers(widget.medication.frequencyPerDay);

    for (int i = 0; i < timeControllers.length; i++) {
      if (i < widget.medication.reminderTimes.length) {
        timeControllers[i].text = widget.medication.reminderTimes[i];
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    timesPerDayController.dispose();
    startDateController.dispose();
    noteController.dispose();

    for (final controller in timeControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _updateTimeControllers(int count) {
    if (count < 1) count = 1;
    if (count > 6) count = 6;

    while (timeControllers.length < count) {
      timeControllers.add(TextEditingController());
    }

    while (timeControllers.length > count) {
      timeControllers.removeLast().dispose();
    }

    timesPerDay = count;
  }

  InputDecoration customInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _pickMedicationImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMedicationImage = image;
      _selectedMedicationImageBytes = bytes;
    });
  }

  void _clearMedicationImage() {
    setState(() {
      _selectedMedicationImage = null;
      _selectedMedicationImageBytes = null;
    });
  }

  Widget _buildMedicationImageSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = widget.medication.imageUrl?.trim();
    final hasNetworkImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medicine Photo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Optional. Updating the photo uploads a new file to Firebase Storage.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 180,
              color: colorScheme.surface,
              child: _selectedMedicationImageBytes != null
                  ? Image.memory(
                      _selectedMedicationImageBytes!,
                      fit: BoxFit.cover,
                    )
                  : hasNetworkImage
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 42,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 42,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No photo selected',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _pickMedicationImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  (_selectedMedicationImageBytes != null || hasNetworkImage)
                      ? 'Change Photo'
                      : 'Upload Photo',
                ),
              ),
              if (_selectedMedicationImageBytes != null)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _clearMedicationImage,
                  icon: const Icon(Icons.close),
                  label: const Text('Reset'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> pickTime(int index) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        timeControllers[index].text = pickedTime.format(context);
      });
    }
  }

  Future<void> pickStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(startDateController.text) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        startDateController.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  String _formatDoseAmount(double value) {
    final hasNoFraction = value == value.truncateToDouble();
    return hasNoFraction ? value.toStringAsFixed(0) : value.toString();
  }

  String _formatDateForInput(DateTime? value) {
    if (value == null) {
      return '';
    }

    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  DraftMedicationInput _buildDraftMedicationInput(
    String medicationId,
    List<String> times,
  ) {
    return DraftMedicationInput(
      existingMedicationId: medicationId,
      name: nameController.text.trim(),
      genericName: widget.medication.genericName,
      brandName: widget.medication.brandName,
      doseAmount: double.tryParse(doseController.text.trim()),
      doseUnit: selectedDoseUnit,
      frequencyPerDay: times.length,
      reminderTimes: times,
      startDate: DateTime.tryParse(startDateController.text.trim()),
      notes: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
      form: widget.medication.form,
    );
  }

  Future<bool> _showSafetyPreview(
    String medicationId,
    List<String> times,
  ) async {
    try {
      final response = await _explanationRepository.generateSafetyPreview(
        draftMedication: _buildDraftMedicationInput(medicationId, times),
      );

      if (!mounted) {
        return false;
      }

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafetyPreviewSheet(
          response: response,
          confirmLabel: 'Save Changes',
        ),
      );

      return confirmed == true;
    } catch (e) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }

  Future<void> updateMedication() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final medicationId = widget.medication.id;

    if (user == null || medicationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update this medication')),
      );
      return;
    }

    for (int i = 0; i < timeControllers.length; i++) {
      if (timeControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please select Time ${i + 1}')));
        return;
      }
    }

    final List<String> times = timeControllers
        .map((controller) => controller.text.trim())
        .toList();

    setState(() {
      isLoading = true;
    });

    final confirmed = await _showSafetyPreview(medicationId, times);
    if (!mounted) return;

    if (!confirmed) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      String? imageUrl = widget.medication.imageUrl;

      if (_selectedMedicationImage != null) {
        imageUrl = await _imageStorageRepository.uploadMedicationImage(
          uid: user.uid,
          medicationId: medicationId,
          image: _selectedMedicationImage!,
        );
      }

      final updatedMedication = widget.medication.copyWith(
        id: medicationId,
        userId: user.uid,
        name: nameController.text.trim(),
        doseAmount: double.parse(doseController.text.trim()),
        doseUnit: selectedDoseUnit,
        frequencyPerDay: times.length,
        scheduledTimes: times
            .map(MedicationScheduleTime.fromDisplayString)
            .toList(growable: false),
        startDate: DateTime.tryParse(startDateController.text.trim()),
        notes: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        imageUrl: imageUrl,
        notificationIds: const <int>[],
      );

      await NotificationService.cancelNotifications(
        widget.medication.notificationIds,
      );

      await _medicationRepository.updateMedicationRecord(
        uid: user.uid,
        medicationId: medicationId,
        medication: updatedMedication,
      );
      final List<int> newNotificationIds =
          await NotificationService.scheduleMedicationReminders(
            medicineName: updatedMedication.name,
            times: updatedMedication.reminderTimes,
            body: 'Time to take ${updatedMedication.name}',
            userId: user.uid,
            medicationId: medicationId,
            startDate: updatedMedication.startDate,
          );

      await _medicationRepository.updateMedicationRecord(
        uid: user.uid,
        medicationId: medicationId,
        medication: updatedMedication.copyWith(
          notificationIds: newNotificationIds,
        ),
      );

      if (!mounted) return;

      if (newNotificationIds.length == times.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication updated successfully')),
        );
      } else if (newNotificationIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Medication updated, but some reminders could not be scheduled.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Medication updated, but reminders could not be scheduled.',
            ),
          ),
        );
      }

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Update failed')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Medication'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: customInputDecoration('Medication Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter medication name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildMedicationImageSection(),
                const SizedBox(height: 14),

                TextFormField(
                  controller: doseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: customInputDecoration('Dosage'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter dosage';
                    }

                    final number = double.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return 'Enter a valid dosage number';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: selectedDoseUnit,
                  decoration: customInputDecoration('Dose Unit'),
                  items: doseUnits.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedDoseUnit = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: timesPerDayController,
                  keyboardType: TextInputType.number,
                  decoration: customInputDecoration('Frequency per day'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the daily frequency';
                    }

                    final number = int.tryParse(value.trim());
                    if (number == null) {
                      return 'Enter a valid number';
                    }

                    if (number < 1 || number > 6) {
                      return 'Times per day must be between 1 and 6';
                    }

                    return null;
                  },
                  onChanged: (value) {
                    if (value.trim().isEmpty) {
                      return;
                    }

                    int parsed = int.tryParse(value) ?? 1;

                    if (parsed > 6) {
                      parsed = 6;
                      timesPerDayController.text = '6';
                      timesPerDayController.selection =
                          TextSelection.fromPosition(TextPosition(offset: 1));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maximum is 6 times per day'),
                        ),
                      );
                    }

                    if (parsed < 1) {
                      parsed = 1;
                    }

                    setState(() {
                      final oldValues = timeControllers
                          .map((controller) => controller.text)
                          .toList();

                      _updateTimeControllers(parsed);

                      for (int i = 0; i < timeControllers.length; i++) {
                        if (i < oldValues.length) {
                          timeControllers[i].text = oldValues[i];
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                Column(
                  children: List.generate(timeControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: timeControllers[index],
                        readOnly: true,
                        onTap: () => pickTime(index),
                        decoration: customInputDecoration(
                          'Reminder Time ${index + 1}',
                        ).copyWith(suffixIcon: const Icon(Icons.access_time)),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select Time ${index + 1}';
                          }
                          return null;
                        },
                      ),
                    );
                  }),
                ),

                TextFormField(
                  controller: startDateController,
                  readOnly: true,
                  onTap: pickStartDate,
                  decoration: customInputDecoration('Start Date'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please choose start date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: customInputDecoration('Notes'),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : updateMedication,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
