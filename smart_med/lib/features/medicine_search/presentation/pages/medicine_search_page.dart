import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_lookup_repository.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';

class MedicineSearchPage extends StatefulWidget {
  const MedicineSearchPage({super.key, this.initialImage});

  final XFile? initialImage;

  @override
  State<MedicineSearchPage> createState() => _MedicineSearchPageState();
}

class _MedicineSearchPageState extends State<MedicineSearchPage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final MedicineLookupRepository _repository = medicineLookupRepository;

  bool _isSearching = false;
  String? _errorMessage;
  MedicineLookupResult? _result;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
    if (_selectedImage != null) {
      _loadSelectedImageBytes();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedImageBytes() async {
    final image = _selectedImage;
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted || _selectedImage != image) {
      return;
    }

    setState(() {
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
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
      _selectedImage = image;
      _selectedImageBytes = bytes;
      _errorMessage = null;
    });
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _errorMessage = null;
    });
  }

  void _applyExample(String value) {
    setState(() {
      _nameController.text = value;
      _errorMessage = null;
    });
  }

  Future<void> _searchByName() async {
    FocusScope.of(context).unfocus();
    await _runSearch(() => _repository.searchByName(_nameController.text));
  }

  Future<void> _searchByImage() async {
    final image = _selectedImage;
    if (image == null) {
      setState(() {
        _errorMessage = 'Choose a medicine image before searching by image.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    await _runSearch(() => _repository.searchByImage(image: image));
  }

  Future<void> _runSearch(
    Future<MedicineLookupResult> Function() loader,
  ) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final result = await loader();
      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _isSearching = false;
      });
    } on MedicineLookupRepositoryException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isSearching = false;
      });
    }
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.medication_liquid_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Search medicine information by name or image',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Get the medicine name, generic name, uses, dose notes, warnings, side effects, interactions, alternatives, storage, and a safety disclaimer from the backend.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSearchCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search by medicine name',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Type a brand or generic name.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.search,
            decoration: _inputDecoration(
              context,
              label: 'Medicine name',
              hint: 'Example: ibuprofen',
            ),
            onSubmitted: (_) {
              if (!_isSearching) {
                _searchByName();
              }
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                label: const Text('Ibuprofen'),
                onPressed: () => _applyExample('ibuprofen'),
              ),
              ActionChip(
                label: const Text('Tylenol'),
                onPressed: () => _applyExample('Tylenol'),
              ),
              ActionChip(
                label: const Text('Amoxicillin'),
                onPressed: () => _applyExample('amoxicillin'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _searchByName,
              icon: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isSearching ? 'Searching...' : 'Search by Name'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSearchCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search by image',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a clear pill, bottle, or package photo. The app reads text visible in the image, then looks up that medicine.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 220,
              color: colorScheme.surface,
              child: _selectedImageBytes == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 44,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No image selected',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isSearching
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
              OutlinedButton.icon(
                onPressed: _isSearching
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
              if (_selectedImageBytes != null)
                OutlinedButton.icon(
                  onPressed: _isSearching ? null : _clearImage,
                  icon: const Icon(Icons.close),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _searchByImage,
              icon: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.image_search_outlined),
              label: Text(_isSearching ? 'Searching...' : 'Search by Image'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    Color? accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedAccent = accentColor ?? colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resolvedAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: resolvedAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
    required String emptyMessage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayItems = items.isEmpty ? <String>[emptyMessage] : items;
    final isPlaceholder = items.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...displayItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: isPlaceholder
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isPlaceholder
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativeSection(
    BuildContext context,
    List<MedicineAlternativeItem> alternatives,
  ) {
    return _buildListSection(
      context,
      icon: Icons.swap_horiz_outlined,
      title: 'Alternatives',
      items: alternatives
          .map((item) => item.displayLabel)
          .toList(growable: false),
      emptyMessage:
          'No related alternative medicines were found in the public data that was checked.',
    );
  }

  Widget _buildResultCard(BuildContext context, MedicineLookupResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedDifferentFromQuery =
        result.query.trim().isNotEmpty &&
        result.medicineName.trim().toLowerCase() !=
            result.query.trim().toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.medicineName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if ((result.genericName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Generic name: ${result.genericName}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if (resolvedDifferentFromQuery) ...[
            const SizedBox(height: 6),
            Text(
              'Searched as: ${result.query}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (result.brandNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Brand names: ${result.brandNames.join(', ')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (result.activeIngredients.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Active ingredients: ${result.activeIngredients.join(', ')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (result.isImageSearch &&
              (result.identificationReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Image search note: ${result.identificationReason}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _buildListSection(
            context,
            icon: Icons.info_outline,
            title: 'Used for',
            items: result.usedFor,
            emptyMessage: 'No public label section for uses was found.',
          ),
          const SizedBox(height: 18),
          _buildListSection(
            context,
            icon: Icons.straighten_outlined,
            title: 'Dose',
            items: result.dose,
            emptyMessage: 'No public dose section was found.',
          ),
          const SizedBox(height: 18),
          _buildListSection(
            context,
            icon: Icons.warning_amber_rounded,
            title: 'Warnings',
            items: result.warnings,
            emptyMessage: 'No public warnings section was found.',
          ),
          const SizedBox(height: 18),
          _buildListSection(
            context,
            icon: Icons.sick_outlined,
            title: 'Side effects',
            items: result.sideEffects,
            emptyMessage: 'No public side-effects section was found.',
          ),
          const SizedBox(height: 18),
          _buildListSection(
            context,
            icon: Icons.compare_arrows_outlined,
            title: 'Interactions',
            items: result.interactions,
            emptyMessage: 'No public interactions section was found.',
          ),
          const SizedBox(height: 18),
          _buildAlternativeSection(context, result.alternatives),
          const SizedBox(height: 18),
          _buildListSection(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Storage',
            items: result.storage,
            emptyMessage: 'No public storage guidance was found.',
          ),
          const SizedBox(height: 18),
          _buildListSection(
            context,
            icon: Icons.gpp_maybe_outlined,
            title: 'Disclaimer',
            items: result.disclaimer,
            emptyMessage:
                'Use a clinician or pharmacist for personal medical advice.',
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(BuildContext context) {
    if (_errorMessage != null) {
      return _buildStateCard(
        context,
        icon: Icons.error_outline,
        title: 'Search failed',
        message: _errorMessage!,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }

    final result = _result;
    if (result != null) {
      return _buildResultCard(context, result);
    }

    return _buildStateCard(
      context,
      icon: Icons.medication_outlined,
      title: 'Ready to search',
      message:
          'Search a medicine by name or image to see medicine information here.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Search')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIntroCard(context),
                const SizedBox(height: 16),
                _buildNameSearchCard(context),
                const SizedBox(height: 16),
                _buildImageSearchCard(context),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildResultState(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
