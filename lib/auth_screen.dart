import 'package:flutter/material.dart';
import 'supabase_initializer.dart'; // أو استخدام السوبابيز المعرف مسبقاً
import 'teacher_dashboard.dart';
import 'student_homeworks_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String _selectedRole = 'student'; // 'teacher' أو 'student'

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال البريد الإلكتروني وكلمة المرور')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'role': _selectedRole},
        );
        
        if (response.user != null) {
          // حفظ دور المستخدم في جدول الـ profiles إذا لزم الأمر
          await supabase.from('profiles').insert({
            'id': response.user!.id,
            'email': email,
            'role': _selectedRole,
            'full_name': email.split('@')[0],
          });
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الحساب بنجاح! يجدر بك تسجیل الدخول الآن.')),
        );
        setState(() => _isSignUp = false);
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        
        // جلب بيانات الدور لتوجيه المستخدم للشاشة المناسبة
        final user = supabase.auth.currentUser;
        if (user != null) {
          final profileData = await supabase
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();

          final role = profileData?['role'] ?? 'student';

          if (!mounted) return;
          if (role == 'teacher') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const StudentHomeworksScreen()),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_rounded, size: 80, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  _isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول للتطبيق',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'اختر نوع الحساب',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('طالب')),
                      DropdownMenuItem(value: 'teacher', child: Text('معلم')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _authenticate,
                    child: _isLoading
                        const CircularProgressIndicator(color: Colors.white)
                        : Text(_isSignUp ? 'تسجيل حساب جديد' : 'دخول'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'لديك حساب بالفعل؟ سجل الدخول'
                        : 'ليس لديك حساب؟ انشئ حساباً جديداً',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
