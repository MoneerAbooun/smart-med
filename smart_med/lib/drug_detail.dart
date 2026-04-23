import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_med/models/drug_details_response.dart';
import 'package:smart_med/services/drug_api_service.dart';

class DrugDetailPage extends StatefulWidget {
  final String searchedDrugName;
  final String? imagePath;

  const DrugDetailPage({
    super.key,
    required this.searchedDrugName,
    this.imagePath,
  });

  @override
  State<DrugDetailPage> createState() => _DrugDetailPageState();
}

class _DrugDetailPageState extends State<DrugDetailPage> {
  final DrugApiService _drugApiService = DrugApiService();

  bool _isLoading = true;
  String? _errorMessage;
  DrugDetailsResponse? _drugDetails;

  @override
  void initState() {
    super.initState();
    _loadDrugDetails();
  }

  Future<void> _loadDrugDetails() async {
    final query = widget.searchedDrugName.trim();

    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Image-only lookup is not connected yet. Please type the medicine name to fetch real drug details.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _drugDetails = null;
    });

    try {
      final details = await _drugApiService.fetchDrugDetails(query);

      if (!mounted) return;

      setState(() {
        _drugDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _normalizeText(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _cleanSectionItems(List<String> rawItems, {int maxItems = 8}) {
    if (rawItems.isEmpty) return [];

    final combined = _normalizeText(rawItems.join(' '));

    final parts = combined
        .split(RegExp(r'(?<=[.;:])\s+'))
        .map(_normalizeText)
        .where((item) => item.isNotEmpty)
        .toList();

    final cleaned = <String>[];
    final seen = <String>{};

    for (final item in parts) {
      final lower = item.toLowerCase();

      if (item.length < 8) continue;
      if (seen.contains(lower)) continue;

      seen.add(lower);
      cleaned.add(item);

      if (cleaned.length >= maxItems) break;
    }

    return cleaned;
  }

  String _singleLineOrFallback(String? value, String fallback) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool hasImage =
        widget.imagePath != null && widget.imagePath!.isNotEmpty;
    final String displayDrugName =
        _drugDetails?.matchedName?.trim().isNotEmpty == true
        ? _drugDetails!.matchedName!.trim()
        : widget.searchedDrugName.trim().isNotEmpty
        ? widget.searchedDrugName.trim()
        : 'Detected Medicine';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Drug Details',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.medication_outlined,
                                size: 34,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayDrugName,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _drugDetails == null
                                        ? hasImage
                                              ? 'Medicine selected from camera or gallery'
                                              : 'Medicine selected from search field'
                                        : 'Source: ${_drugDetails!.source}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_drugDetails?.rxcui != null &&
                                      _drugDetails!.rxcui!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'RXCUI: ${_drugDetails!.rxcui!}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasImage) ...[
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 10,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.file(
                                  File(widget.imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Loading drug details...'),
                      ],
                    ),
                  )
                else if (_errorMessage != null)
                  _StatusCard(
                    icon: Icons.error_outline,
                    title: 'Unable to load drug details',
                    message: _errorMessage!,
                    buttonText: 'Retry',
                    onPressed: _loadDrugDetails,
                  )
                else if (_drugDetails == null)
                  _StatusCard(
                    icon: Icons.search_off_outlined,
                    title: 'No data found',
                    message: 'No drug details are available for this medicine.',
                    buttonText: 'Try Again',
                    onPressed: _loadDrugDetails,
                  )
                else
                  Column(
                    children: [
                      _InfoBox(
                        title: 'Generic Name',
                        icon: Icons.science_outlined,
                        content: _singleLineOrFallback(
                          _drugDetails!.genericName,
                          'No generic name available.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ExpandableDetailBox(
                        title: 'Brand Names',
                        icon: Icons.local_pharmacy_outlined,
                        items: _cleanSectionItems(
                          _drugDetails!.brandNames,
                          maxItems: 6,
                        ),
                        fallback: 'No brand names available.',
                      ),
                      const SizedBox(height: 14),
                      _ExpandableDetailBox(
                        title: 'Active Ingredients',
                        icon: Icons.biotech_outlined,
                        items: _cleanSectionItems(
                          _drugDetails!.activeIngredients,
                          maxItems: 6,
                        ),
                        fallback: 'No active ingredient data available.',
                      ),
                      const SizedBox(height: 14),
                      _ExpandableDetailBox(
                        title: 'Uses',
                        icon: Icons.healing_outlined,
                        items: _cleanSectionItems(
                          _drugDetails!.uses,
                          maxItems: 8,
                        ),
                        fallback: 'No uses information available.',
                      ),
                      const SizedBox(height: 14),
                      _ExpandableDetailBox(
                        title: 'Warnings',
                        icon: Icons.warning_amber_rounded,
                        items: _cleanSectionItems(
                          _drugDetails!.warnings,
                          maxItems: 10,
                        ),
                        fallback: 'No warnings information available.',
                        highlight: true,
                      ),
                      const SizedBox(height: 14),
                      _ExpandableDetailBox(
                        title: 'Side Effects',
                        icon: Icons.report_problem_outlined,
                        items: _cleanSectionItems(
                          _drugDetails!.sideEffects,
                          maxItems: 8,
                        ),
                        fallback: 'No side effects listed.',
                      ),
                      const SizedBox(height: 14),
                      _ExpandableDetailBox(
                        title: 'Dosage Notes',
                        icon: Icons.monitor_weight_outlined,
                        items: _cleanSectionItems(
                          _drugDetails!.dosageNotes,
                          maxItems: 8,
                        ),
                        fallback: 'No dosage notes available.',
                      ),
                      const SizedBox(height: 14),
                      _ExpandableDetailBox(
                        title: 'Contraindications',
                        icon: Icons.do_not_disturb_alt_outlined,
                        items: _cleanSectionItems(
                          _drugDetails!.contraindications,
                          maxItems: 6,
                        ),
                        fallback: 'No contraindications listed.',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const _InfoBox({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              content,
              style: TextStyle(
                height: 1.4,
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableDetailBox extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String fallback;
  final bool highlight;

  const _ExpandableDetailBox({
    required this.title,
    required this.icon,
    required this.items,
    required this.fallback,
    this.highlight = false,
  });

  @override
  State<_ExpandableDetailBox> createState() => _ExpandableDetailBoxState();
}

class _ExpandableDetailBoxState extends State<_ExpandableDetailBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final items = widget.items;
    final hasItems = items.isNotEmpty;
    final visibleItems = _expanded || items.length <= 3
        ? items
        : items.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.highlight
            ? colorScheme.errorContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.highlight
              ? colorScheme.error.withValues(alpha: 0.35)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.highlight
                    ? colorScheme.error
                    : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: !hasItems
                ? Text(
                    widget.fallback,
                    style: TextStyle(
                      height: 1.4,
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...visibleItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('- '),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    height: 1.4,
                                    fontSize: 15,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (items.length > 3)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _expanded = !_expanded;
                              });
                            },
                            child: Text(_expanded ? 'Show less' : 'Show more'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
