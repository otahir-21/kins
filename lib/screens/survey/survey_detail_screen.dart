import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/models/survey_model.dart';
import 'package:kins_app/models/survey_question_model.dart';
import 'package:kins_app/repositories/surveys_repository.dart';

/// Survey as banner slider: one question per slide. Question on top, options in a row.
/// On tap option → animation → results view (bars + percentages + checkmark). Then Submit when all done.
class SurveyDetailScreen extends StatefulWidget {
  const SurveyDetailScreen({
    super.key,
    required this.surveyId,
    this.initialTitle,
  });

  final String surveyId;
  final String? initialTitle;

  @override
  State<SurveyDetailScreen> createState() => _SurveyDetailScreenState();
}

class _SurveyDetailScreenState extends State<SurveyDetailScreen> {
  SurveyModel? _survey;
  bool _alreadyResponded = false;
  bool _loading = true;
  String? _error;
  final Map<String, String> _selected = {}; // questionId -> optionId
  final Map<String, bool> _showResults = {}; // questionId -> show results view
  late PageController _pageController;
  int _currentPage = 0;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responded = await SurveysRepository.getMyResponse(widget.surveyId);
      if (responded) {
        setState(() {
          _alreadyResponded = true;
          _loading = false;
        });
        return;
      }
      final survey = await SurveysRepository.getSurvey(widget.surveyId);
      if (mounted) {
        setState(() {
          _survey = survey;
          _loading = false;
          if (survey == null) _error = 'Survey not found';
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

  void _onOptionTap(SurveyQuestionModel q, String optionId) {
    if (_selected.containsKey(q.id)) return; // already answered
    setState(() {
      _selected[q.id] = optionId;
      _showResults[q.id] = true;
    });
  }

  bool get _allAnswered {
    if (_survey == null) return false;
    for (final q in _survey!.questions) {
      if (!_selected.containsKey(q.id) || _selected[q.id]!.isEmpty) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_survey == null || !_allAnswered) return;
    final responses = _selected.entries
        .map((e) => {'questionId': e.key, 'optionId': e.value})
        .toList();
    try {
      await SurveysRepository.submitResponse(widget.surveyId, responses);
      if (mounted) {
        setState(() => _submitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks! Your response was saved.')),
        );
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87, size: Responsive.fontSize(context, 24)),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          _survey?.title ?? widget.initialTitle ?? 'Survey',
          style: TextStyle(
            color: Colors.black87,
            fontSize: Responsive.fontSize(context, 18),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C1D54)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _alreadyResponded
                  ? _buildAlreadyAnswered()
                  : _submitted
                      ? _buildThankYou()
                      : _buildBannerSlider(),
    );
  }

  Widget _buildAlreadyAnswered() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.screenPaddingH(context) * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade600),
            SizedBox(height: Responsive.spacing(context, 16)),
            Text(
              "You've already answered this survey.",
              style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w500, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.spacing(context, 24)),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text('Back'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C1D54), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThankYou() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
          SizedBox(height: Responsive.spacing(context, 16)),
          Text(
            'Thank you!',
            style: TextStyle(fontSize: Responsive.fontSize(context, 20), fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          SizedBox(height: Responsive.spacing(context, 8)),
          Text(
            'Your response was saved.',
            style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSlider() {
    final survey = _survey!;
    final questions = survey.questions;
    if (questions.isEmpty) {
      return const Center(child: Text('No questions in this survey.'));
    }

    const double indicatorStripHeight = 36;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              final showResults = _showResults[q.id] == true;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: showResults
                      ? _buildResultsCard(q)
                      : _buildQuestionCard(q),
                ),
              );
            },
          ),
        ),
        // Dots container under the slider (like ads banner)
        Container(
          height: indicatorStripHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              questions.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentPage ? const Color(0xFF7C1D54) : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ),
        // Submit button when all answered
        if (_allAnswered)
          Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.screenPaddingH(context),
              Responsive.spacing(context, 16),
              Responsive.screenPaddingH(context),
              Responsive.spacing(context, 24),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C1D54),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 14)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Submit survey', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
              ),
            ),
          )
        else
          SizedBox(height: Responsive.spacing(context, 24)),
      ],
    );
  }

  /// First view: question on top, options in a row.
  Widget _buildQuestionCard(SurveyQuestionModel q) {
    return Container(
      key: ValueKey('q-${q.id}'),
      margin: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.text,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 17),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 20)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: q.options.map((opt) {
                return Padding(
                  padding: EdgeInsets.only(right: Responsive.spacing(context, 10)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onOptionTap(q, opt.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.spacing(context, 16),
                          vertical: Responsive.spacing(context, 12),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          opt.text,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Results view after tap: bars + percentages + checkmark on selected.
  Widget _buildResultsCard(SurveyQuestionModel q) {
    final selectedId = _selected[q.id];
    // Placeholder percentages (selected option gets a bump for demo)
    final optionCount = q.options.length;
    final percents = List<int>.filled(optionCount, 100 ~/ optionCount);
    final selectedIndex = q.options.indexWhere((o) => o.id == selectedId);
    if (selectedIndex >= 0 && optionCount > 0) {
      percents[selectedIndex] = (percents[selectedIndex] + 20).clamp(0, 100);
      int sum = percents.reduce((a, b) => a + b);
      if (sum != 100) percents[selectedIndex] = percents[selectedIndex] + (100 - sum);
    }

    return Container(
      key: ValueKey('r-${q.id}'),
      margin: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.text,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 17),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 16)),
          ...List.generate(q.options.length, (i) {
            final opt = q.options[i];
            final percent = percents[i].clamp(0, 100);
            final isSelected = opt.id == selectedId;
            return Padding(
              padding: EdgeInsets.only(bottom: Responsive.spacing(context, 12)),
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.grey.shade300 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent / 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C1D54).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 12)),
                          child: Text(
                            opt.text,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: Responsive.spacing(context, 8)),
                  if (isSelected)
                    Icon(Icons.check_box, color: const Color(0xFF7C1D54), size: 24),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Constrains child to a fraction of parent width. Parent must have bounded width.
class FractionallySizedBox extends StatelessWidget {
  const FractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
  });

  final double widthFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth * widthFactor.clamp(0.0, 1.0);
        return SizedBox(width: w, child: child);
      },
    );
  }
}
