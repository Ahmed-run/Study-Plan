import 'package:flutter/material.dart';
import 'main.dart'; // للوصول لمتغير supabase
import 'generate_homework_screen.dart';
import 'teacher_homeworks_screen.dart';
import 'auth_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('classes')
          .select()
          .eq('teacher_id', user.id);

      setState(() {
        _classes = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الفصول: $e')),
      );
    }
  }

  void _addClassDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فصل جديد'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم الفصل أو المرحلة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              
              final user = supabase.auth.currentUser;
              if (user == null) return;

              await supabase.from('classes').insert({
                'name': name,
                'teacher_id': user.id,
              });

              Navigator.pop(context);
              _loadClasses();
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة تحكم المعلم'),
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
            : _classes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('لا توجد فصول مضافة حالياً'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _addClassDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة فصل جديد'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _classes.length,
                    itemBuilder: (context, index) {
                      final c = _classes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.class_rounded, size: 36),
                          title: Text(c['name'] ?? 'بدون اسم',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('اضغط لإدارة الواجبات وتوليد الأسئلة'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeacherHomeworksListScreen(
                                  classId: c['id'].toString(),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
        floatingActionButton: _classes.isNotEmpty
            ? FloatingActionButton(
                onPressed: _addClassDialog,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}
