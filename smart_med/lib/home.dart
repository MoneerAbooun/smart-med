import 'dart:io';
import 'package:smart_med/medication_list.dart';

import 'drug_detail.dart';
import 'drug_interaction.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'alternative.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isCameraOpened = false;
  bool isCapturing = false;

  final TextEditingController searchController = TextEditingController();
  CameraController? controller;
  Future<void>? initializeControllerFuture;
  final ImagePicker _picker = ImagePicker();

  XFile? selectedImage;

  Future<void> _setupCamera() async {
    if (widget.cameras.isEmpty) {
      throw Exception("No cameras available");
    }

    final backCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    initializeControllerFuture = controller!.initialize();
    await initializeControllerFuture;
  }

  Future<void> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        isCameraOpened = false;
        isCapturing = false;
      });
    }
  }

  Future<void> openCamera() async {
    try {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }

      await _setupCamera();

      if (!mounted) return;

      setState(() {
        isCameraOpened = true;
        selectedImage = null;
        isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to open camera: $e")));
    }
  }

  Future<void> captureImage() async {
    if (controller == null) return;
    if (!controller!.value.isInitialized) return;
    if (controller!.value.isTakingPicture || isCapturing) return;

    try {
      setState(() {
        isCapturing = true;
      });

      await initializeControllerFuture;

      final XFile image = await controller!.takePicture();

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        isCameraOpened = false;
        isCapturing = false;
      });

      await controller!.dispose();
      controller = null;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isCapturing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to capture image: $e")));
    }
  }

  Future<void> backToPlaceholder() async {
    if (controller != null) {
      await controller!.dispose();
      controller = null;
    }

    if (!mounted) return;

    setState(() {
      selectedImage = null;
      isCameraOpened = false;
      isCapturing = false;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          toolbarHeight: 70,
          centerTitle: true,
          automaticallyImplyLeading: false,

          leadingWidth: 56,
          leading: const SizedBox(),

          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/Capsule.png', fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text(
                'Smart Med',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          actions: [
            SizedBox(
              width: 56,
              child: IconButton(
                icon: const Icon(Icons.medication_outlined, size: 28),
                tooltip: 'Medications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MedicationListPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 330,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: selectedImage != null
                          ? Image.file(
                              File(selectedImage!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : isCameraOpened
                          ? FutureBuilder(
                              future: initializeControllerFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    controller != null) {
                                  return CameraPreview(controller!);
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            )
                          : Center(
                              child: InkWell(
                                onTap: openCamera,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      size: 80,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 15),
                                    Text(
                                      "Tap to open camera",
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedImage != null || isCameraOpened)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: backToPlaceholder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.surface,
                            foregroundColor: colorScheme.onSurface,
                            minimumSize: const Size(100, 45),
                          ),
                          child: const Text("Back"),
                        ),
                        const SizedBox(width: 12),
                        if (isCameraOpened)
                          ElevatedButton.icon(
                            onPressed: isCapturing ? null : captureImage,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(180, 45),
                            ),
                            icon: const Icon(Icons.camera),
                            label: Text(
                              isCapturing ? "Capturing..." : "Capture Image",
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "Search medications",
                      suffixIcon: IconButton(
                        onPressed: pickImageFromGallery,
                        icon: const Icon(Icons.image),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Column(
                    children: [
                      SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: () {
                            final drugName = searchController.text.trim();
                            final hasImage = selectedImage != null;

                            if (drugName.isEmpty && !hasImage) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a drug name or select an image first',
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DrugDetailPage(
                                  searchedDrugName: drugName,
                                  imagePath: selectedImage?.path,
                                ),
                              ),
                            );
                          },
                          child: const Text("Drug Details"),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DrugInteractionPage(),
                                  ),
                                );
                              },
                              child: const Text("Interaction"),
                            ),
                          ),

                          const SizedBox(width: 12),
                          SizedBox(
                            width: 140,
                            child: ElevatedButton(
                              onPressed: () {
                                final drugName = searchController.text.trim();
                                final hasImage = selectedImage != null;

                                if (drugName.isEmpty && !hasImage) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a drug name or select an image first',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AlternativePage(
                                      searchedDrugName: drugName,
                                      imagePath: selectedImage?.path,
                                    ),
                                  ),
                                );
                              },
                              child: const Text("Alternatives"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
