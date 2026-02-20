/// One selectable option for a survey question.
class SurveyOptionModel {
  final String id;
  final String text;

  SurveyOptionModel({required this.id, required this.text});

  factory SurveyOptionModel.fromJson(Map<String, dynamic> json) {
    return SurveyOptionModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}
