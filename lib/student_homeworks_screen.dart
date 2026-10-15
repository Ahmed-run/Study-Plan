import 'package:flutter/material.dart';
import 'main.dart';
import 'solve_homework_screen.dart';
import 'auth_screen.dart';

class StudentHomeworksScreen extends StatefulWidget {
  const StudentHomeworksScreen({super.key});

  @override
  State<StudentHomeworksScreen> createState() => _StudentHomeworksScreenState();
}

class _StudentHomeworksScreenState extends State<StudentHomeworksScreen> {
  List<Map<String, dynamic>> _homeworks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeworks();
  }

  Future<void> _loadHomeworks() async {
    try {
      final data = await supabase
          .from('homeworks')
          .select('id, title, lesson, created_at')
          .order('created_at', ascending: false);

      setState(() {
        _homeworks = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الواجبات: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الواجبات المتاحة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await supabase.auth.signOut();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _homeworks.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد واجبات متاحة للحل حالياً',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _homeworks.length,
                    itemBuilder: (context, index) {
                      final hw = _homeworks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.assignment_outlined, size: 36),
                          title: Text(
                            hw['title'] ?? 'واجب بدون عنوان',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('الدرس: ${hw['lesson'] ?? '-'}'),
                          trailing: const FilledButton(
                            onPressed: null, // التفاعل عند ضغط الكارت
                            child: Text('بدء الحل'),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SolveHomeworkScreen(
                                  homeworkId: hw['id'].toString(),
                                  homeworkTitle: hw['title'] ?? 'حل الواجب',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
