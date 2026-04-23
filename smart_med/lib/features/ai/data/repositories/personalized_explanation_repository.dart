import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_med/core/network/api_client.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';

class PersonalizedExplanationRepositoryException implements Exception {
  const PersonalizedExplanationRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PersonalizedExplanationRepository {
  PersonalizedExplanationRepository({
    FirebaseAuth? firebaseAuth,
    ApiClient? apiClient,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _apiClient = apiClient ?? ApiClient();

  final FirebaseAuth _firebaseAuth;
  final ApiClient _apiClient;

  Future<PersonalizedExplanationResponse> generateExplanation({
    List<String> medicationIds = const <String>[],
    bool includeInactive = false,
    bool simpleLanguage = true,
  }) async {
    return _sendRequest(
      body: <String, dynamic>{
        'view': 'detail',
        'medication_ids': medicationIds,
        'include_inactive': includeInactive,
        'simple_language': simpleLanguage,
      },
    );
  }

  Future<PersonalizedExplanationResponse> generateSafetyBrief({
    bool includeInactive = false,
    bool simpleLanguage = true,
  }) async {
    return _sendRequest(
      body: <String, dynamic>{
        'view': 'brief',
        'include_inactive': includeInactive,
        'simple_language': simpleLanguage,
      },
    );
  }

  Future<PersonalizedExplanationResponse> generateSafetyPreview({
    required DraftMedicationInput draftMedication,
    bool simpleLanguage = true,
  }) async {
    return _sendRequest(
      body: <String, dynamic>{
        'view': 'preview',
        'simple_language': simpleLanguage,
        'draft_medication': draftMedication.toMap(),
      },
    );
  }

  Future<PersonalizedExplanationResponse> _sendRequest({
    required Map<String, dynamic> body,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const PersonalizedExplanationRepositoryException(
        'Please sign in again to generate an explanation.',
      );
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const PersonalizedExplanationRepositoryException(
        'Could not get a Firebase ID token for this request.',
      );
    }

    try {
      final response = await _apiClient.postJson(
        path: '/personalized-explanation',
        headers: <String, String>{'Authorization': 'Bearer $idToken'},
        body: body,
      );

      return PersonalizedExplanationResponse.fromMap(response);
    } on ApiClientException catch (error) {
      throw PersonalizedExplanationRepositoryException(error.message);
    } catch (error) {
      throw PersonalizedExplanationRepositoryException(error.toString());
    }
  }
}

final PersonalizedExplanationRepository personalizedExplanationRepository =
    PersonalizedExplanationRepository();
