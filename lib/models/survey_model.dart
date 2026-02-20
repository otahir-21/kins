import 'package:kins_app/models/survey_question_model.dart';

/// Survey from GET /surveys/for-me (list) or GET /surveys/:id (full form).
class SurveyModel {
  final String id;
  final String title;
  final String? description;
  final List<SurveyQuestionModel> questions;

  SurveyModel({
    required this.id,
    required this.title,
    this.description,
    required this.questions,
  });

  factory SurveyModel.fromJson(Map<String, dynamic> json) {
    final qList = json['questions'];
    List<SurveyQuestionModel> questions = [];
    if (qList is List) {
      for (final q in qList) {
        if (q is Map<String, dynamic>) questions.add(SurveyQuestionModel.fromJson(q));
      }
    }
    return SurveyModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      questions: questions,
    );
  }
}
