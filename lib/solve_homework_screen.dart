import 'package:flutter/material.dart';
import 'main.dart';

class SolveHomeworkScreen extends StatefulWidget {
  final String homeworkId;
  final String homeworkTitle;

  const SolveHomeworkScreen({
    super.key,
    required this.homeworkId,
    required this.homeworkTitle,
  });

  @override
  State<SolveHomeworkScreen> createState() => _SolveHomeworkScreenState();
}

class _SolveHomeworkScreenState extends State<SolveHomeworkScreen> {
  List<Map<String, dynamic>> _questions = [];
  final Map<int, String> _selectedAnswers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final data = await supabase
          .from('questions')
          .select()
          .eq('homework_id', widget.homeworkId);

      setState(() {
        _questions = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الأسئلة: $e')),
      );
    }
  }

  Future<void> _submitHomework() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_selectedAnswers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء الإجابة على جميع الأسئلة قبل الإرسال')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. إنشاء سجل التسليم في جدول submissions
      final submissionRes = await supabase.from('submissions').insert({
        'homework_id': widget.homeworkId,
        'student_id': user.id,
      }).select().single();

      final submissionId = submissionRes['id'];

      // 2. حفظ إجابات الطالب
      final List<Map<String, dynamic>> answersToInsert = [];
      _selectedAnswers.forEach((questionIndex, answer) {
        answersToInsert.add({
          'submission_id': submissionId,
          'question_id': _questions[questionIndex]['id'],
          'selected_option': answer,
        });
      });

      await supabase.from('student_answers').insert(answersToInsert);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسليم الواجب بنجاح!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التسليم: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.homeworkTitle),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
                ? const Center(child: Text('لا توجد أسئلة لهذه الواجب بعد'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _questions.length + 1, // الزيادة لزر الإرسال في النهاية
                    itemBuilder: (context, index) {
                      if (index == _questions.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submitHomework,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_isSubmitting ? 'جاري التسليم...' : 'إرسال الحل النهائي'),
                          ),
                        );
                      }

                      final q = _questions[index];
                      final options = List<String>.from(q['options'] ?? []);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'السؤال ${index + 1}: ${q['question_text']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...options.map((opt) {
                                return RadioListTile<String>(
                                  title: Text(opt),
                                  value: opt,
                                  groupValue: _selectedAnswers[index],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedAnswers[index] = val!;
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
