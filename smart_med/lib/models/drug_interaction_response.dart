class DrugInteractionResponse {
  final String firstQuery;
  final String secondQuery;
  final String firstDrug;
  final String secondDrug;
  final String? firstGenericName;
  final String? secondGenericName;
  final String? firstRxcui;
  final String? secondRxcui;
  final String? firstSetId;
  final String? secondSetId;
  final String severity;
  final String summary;
  final String? mechanism;
  final List<String> warnings;
  final List<String> recommendations;
  final List<String> evidence;
  final String source;

  const DrugInteractionResponse({
    required this.firstQuery,
    required this.secondQuery,
    required this.firstDrug,
    required this.secondDrug,
    required this.firstGenericName,
    required this.secondGenericName,
    required this.firstRxcui,
    required this.secondRxcui,
    required this.firstSetId,
    required this.secondSetId,
    required this.severity,
    required this.summary,
    required this.mechanism,
    required this.warnings,
    required this.recommendations,
    required this.evidence,
    required this.source,
  });

  factory DrugInteractionResponse.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return <String>[];
    }

    return DrugInteractionResponse(
      firstQuery: (json['first_query'] ?? '').toString(),
      secondQuery: (json['second_query'] ?? '').toString(),
      firstDrug: (json['first_drug'] ?? '').toString(),
      secondDrug: (json['second_drug'] ?? '').toString(),
      firstGenericName: json['first_generic_name']?.toString(),
      secondGenericName: json['second_generic_name']?.toString(),
      firstRxcui: json['first_rxcui']?.toString(),
      secondRxcui: json['second_rxcui']?.toString(),
      firstSetId: json['first_set_id']?.toString(),
      secondSetId: json['second_set_id']?.toString(),
      severity: (json['severity'] ?? 'Unknown').toString(),
      summary: (json['summary'] ?? '').toString(),
      mechanism: json['mechanism']?.toString(),
      warnings: toStringList(json['warnings']),
      recommendations: toStringList(json['recommendations']),
      evidence: toStringList(json['evidence']),
      source: (json['source'] ?? '').toString(),
    );
  }
}
