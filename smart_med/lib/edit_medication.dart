import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_med/services/notification_servicce.dart';

class EditMedicationPage extends StatefulWidget {
  final String docId;
  final String name;
  final num dose;
  final String doseUnit;
  final int timesPerDay;
  final List<dynamic> times;
  final String startDate;
  final String note;

  const EditMedicationPage({
    super.key,
    required this.docId,
    required this.name,
    required this.dose,
    required this.doseUnit,
    required this.timesPerDay,
    required this.times,
    required this.startDate,
    required this.note,
  });

  @override
  State<EditMedicationPage> createState() => _EditMedicationPageState();
}

class _EditMedicationPageState extends State<EditMedicationPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController doseController;
  late TextEditingController timesPerDayController;
  late TextEditingController startDateController;
  late TextEditingController noteController;

  final List<TextEditingController> timeControllers = [];

  bool isLoading = false;
  int timesPerDay = 1;

  final List<String> doseUnits = ['mg', 'ml', 'tablet', 'capsule'];
  late String selectedDoseUnit;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.name);
    doseController = TextEditingController(text: widget.dose.toString());
    timesPerDayController = TextEditingController(
      text: widget.timesPerDay.toString(),
    );
    startDateController = TextEditingController(text: widget.startDate);
    noteController = TextEditingController(text: widget.note);

    selectedDoseUnit = doseUnits.contains(widget.doseUnit)
        ? widget.doseUnit
        : 'mg';

    _updateTimeControllers(widget.timesPerDay);

    for (int i = 0; i < timeControllers.length; i++) {
      if (i < widget.times.length) {
        timeControllers[i].text = widget.times[i].toString();
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

  Future<void> updateMedication() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No logged in user found')));
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

    try {
      final docRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('medications')
          .doc(widget.docId);

      final docSnapshot = await docRef.get();
      final data = docSnapshot.data();

      final List<dynamic> oldNotificationIds = data?['notificationIds'] is List
          ? List<dynamic>.from(data!['notificationIds'])
          : [];

      await NotificationService.cancelNotifications(oldNotificationIds);

      await docRef.update({
        'name': nameController.text.trim(),
        'dose': double.parse(doseController.text.trim()),
        'doseUnit': selectedDoseUnit,
        'timesPerDay': timesPerDay,
        'times': times,
        'startDate': startDateController.text.trim(),
        'note': noteController.text.trim(),
        'notificationIds': [],
      });
      final List<int> newNotificationIds =
          await NotificationService.scheduleMedicationReminders(
            medicineName: nameController.text.trim(),
            times: times,
            body: 'Time to take ${nameController.text.trim()}',
          );

      await docRef.update({'notificationIds': newNotificationIds});

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

                TextFormField(
                  controller: doseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: customInputDecoration('Dose'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter dose';
                    }

                    final number = double.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return 'Enter a valid dose number';
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
                  decoration: customInputDecoration('Times per day'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter times per day';
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
                          'Time ${index + 1}',
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
                  decoration: customInputDecoration('Note'),
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
