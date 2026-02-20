import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/models/survey_model.dart';
import 'package:kins_app/repositories/surveys_repository.dart';

/// Home section: "Surveys" header + cards from GET /surveys/for-me. Tap opens detail; after submit list refreshes.
class SurveysSection extends StatefulWidget {
  const SurveysSection({super.key});

  @override
  State<SurveysSection> createState() => _SurveysSectionState();
}

class _SurveysSectionState extends State<SurveysSection> {
  List<SurveyModel> _surveys = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await SurveysRepository.getForMe();
      if (mounted) {
        setState(() {
          _surveys = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
        });
      }
    }
  }

  void _openSurvey(SurveyModel survey) async {
    final result = await context.push<bool>(
      '/surveys/${survey.id}',
      extra: {'title': survey.title},
    );
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: EdgeInsets.all(Responsive.spacing(context, 20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Surveys',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 16)),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF7C1D54)),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: EdgeInsets.all(Responsive.spacing(context, 20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Surveys',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 12)),
            Text(
              _error!,
              style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: Colors.grey.shade700),
            ),
            SizedBox(height: Responsive.spacing(context, 8)),
            TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_surveys.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, 20),
          vertical: Responsive.spacing(context, 24),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Surveys',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 12)),
            Row(
              children: [
                Icon(Icons.ballot_outlined, size: 20, color: Colors.grey.shade500),
                SizedBox(width: Responsive.spacing(context, 8)),
                Expanded(
                  child: Text(
                    'No surveys right now. Check back later!',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.spacing(context, 20),
              Responsive.spacing(context, 20),
              Responsive.spacing(context, 20),
              0,
            ),
            child: Row(
              children: [
                Icon(Icons.ballot_outlined, size: 22, color: const Color(0xFF7C1D54)),
                SizedBox(width: Responsive.spacing(context, 8)),
                Text(
                  'Surveys',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 12)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              Responsive.screenPaddingH(context),
              0,
              Responsive.screenPaddingH(context),
              Responsive.spacing(context, 20),
            ),
            itemCount: _surveys.length,
            separatorBuilder: (_, __) => SizedBox(height: Responsive.spacing(context, 12)),
            itemBuilder: (context, index) {
              final survey = _surveys[index];
              return _SurveyCard(
                title: survey.title,
                description: survey.description,
                onTap: () => _openSurvey(survey),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.title,
    this.description,
    required this.onTap,
  });

  final String title;
  final String? description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 16)),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C1D54).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.quiz_outlined, color: Color(0xFF7C1D54), size: 24),
              ),
              SizedBox(width: Responsive.spacing(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 15),
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null && description!.isNotEmpty) ...[
                      SizedBox(height: Responsive.spacing(context, 4)),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 13),
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
