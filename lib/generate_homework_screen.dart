import 'package:flutter/material.dart';
import 'main.dart';

class GenerateHomeworkScreen extends StatefulWidget {
  final String classId;
  const GenerateHomeworkScreen({super.key, required this.classId});

  @override
  State<GenerateHomeworkScreen> createState() => _GenerateHomeworkScreenState();
}

class _GenerateHomeworkScreenState extends State<GenerateHomeworkScreen> {
  final _titleController = TextEditingController();
  final _lessonController = TextEditingController();
  final _promptController = TextEditingController();
  bool _isGenerating = false;

  Future<void> _generateHomework() async {
    final title = _titleController.text.trim();
    final lesson = _lessonController.text.trim();
    final customPrompt = _promptController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال عنوان الواجب')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // الاستدعاء لـ Edge Function بالـ Supabase
      final res = await supabase.functions.invoke(
        'generate-homework',
        body: {
          'class_id': widget.classId,
          'title': title,
          'lesson': lesson,
          'prompt': customPrompt,
        },
      );

      if (!mounted) return;

      if (res.status == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الواجب والأسئلة بنجاح!')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('فشل التوليد: ${res.data}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التوليد: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('توليد واجب بالذكاء الاصطناعي'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الواجب (مثال: واجب الدرس الأول)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lessonController,
                decoration: const InputDecoration(
                  labelText: 'اسم الدرس / الفصل',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'تعليمات إضافية للذكاء الاصطناعي (اختياري)',
                  hintText: 'مثال: ركز على الأسئلة المقالية أو الاختيارية الصعبة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateHomework,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'جاري توليد الأسئلة...' : 'توليد الأسئلة الآن'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
