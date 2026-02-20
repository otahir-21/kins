import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/survey_model.dart';

/// Surveys: GET for-me, GET :id, POST respond, GET my-response (all with JWT except GET :id optional).
class SurveysRepository {
  /// Surveys the user has not answered yet. JWT required.
  static Future<List<SurveyModel>> getForMe() async {
    try {
      final raw = await BackendApiClient.get('/surveys/for-me');
      final list = raw['surveys'] ?? raw['data'];
      if (list is! List || list.isEmpty) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => SurveyModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('❌ SurveysRepository.getForMe: $e');
      rethrow;
    }
  }

  /// Full survey (title, questions, options). Auth optional.
  static Future<SurveyModel?> getSurvey(String surveyId) async {
    try {
      final raw = await BackendApiClient.get('/surveys/$surveyId');
      final data = raw['survey'] ?? raw;
      if (data is! Map<String, dynamic>) return null;
      return SurveyModel.fromJson(data);
    } catch (e) {
      debugPrint('❌ SurveysRepository.getSurvey: $e');
      rethrow;
    }
  }

  /// Submit response. JWT required. responses: [{ questionId, optionId }, ...].
  static Future<void> submitResponse(
    String surveyId,
    List<Map<String, String>> responses,
  ) async {
    try {
      await BackendApiClient.post(
        '/surveys/$surveyId/respond',
        body: {'responses': responses},
      );
    } catch (e) {
      debugPrint('❌ SurveysRepository.submitResponse: $e');
      rethrow;
    }
  }

  /// Check if user already answered. JWT required. Returns true if responded.
  static Future<bool> getMyResponse(String surveyId) async {
    try {
      final raw = await BackendApiClient.get('/surveys/$surveyId/my-response');
      final responded = raw['responded'];
      return responded == true;
    } catch (e) {
      debugPrint('❌ SurveysRepository.getMyResponse: $e');
      return false;
    }
  }
}
