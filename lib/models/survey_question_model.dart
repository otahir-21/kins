import 'package:kins_app/models/survey_option_model.dart';

/// One question in a survey (text + options).
class SurveyQuestionModel {
  final String id;
  final String text;
  final List<SurveyOptionModel> options;

  SurveyQuestionModel({
    required this.id,
    required this.text,
    required this.options,
  });

  factory SurveyQuestionModel.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    List<SurveyOptionModel> list = [];
    if (opts is List) {
      for (final o in opts) {
        if (o is Map<String, dynamic>) list.add(SurveyOptionModel.fromJson(o));
      }
    }
    return SurveyQuestionModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      options: list,
    );
  }
}
