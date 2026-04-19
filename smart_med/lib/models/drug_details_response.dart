class DrugDetailsResponse {
  final String query;
  final String? matchedName;
  final String? genericName;
  final List<String> brandNames;
  final List<String> activeIngredients;
  final List<String> uses;
  final List<String> warnings;
  final List<String> sideEffects;
  final List<String> dosageNotes;
  final List<String> contraindications;
  final String source;
  final String? rxcui;
  final String? setId;

  const DrugDetailsResponse({
    required this.query,
    required this.matchedName,
    required this.genericName,
    required this.brandNames,
    required this.activeIngredients,
    required this.uses,
    required this.warnings,
    required this.sideEffects,
    required this.dosageNotes,
    required this.contraindications,
    required this.source,
    required this.rxcui,
    required this.setId,
  });

  factory DrugDetailsResponse.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return <String>[];
    }

    return DrugDetailsResponse(
      query: (json['query'] ?? '').toString(),
      matchedName: json['matched_name']?.toString(),
      genericName: json['generic_name']?.toString(),
      brandNames: toStringList(json['brand_names']),
      activeIngredients: toStringList(json['active_ingredients']),
      uses: toStringList(json['uses']),
      warnings: toStringList(json['warnings']),
      sideEffects: toStringList(json['side_effects']),
      dosageNotes: toStringList(json['dosage_notes']),
      contraindications: toStringList(json['contraindications']),
      source: (json['source'] ?? '').toString(),
      rxcui: json['rxcui']?.toString(),
      setId: json['set_id']?.toString(),
    );
  }
}
