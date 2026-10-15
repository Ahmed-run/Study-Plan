import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// ============================================================
// Models
// ============================================================

class Homework {
  final String id;
  final String title;
  final String? lesson;
  final DateTime? createdAt;

  const Homework({
    required this.id,
    required this.title,
    this.lesson,
    this.createdAt,
  });

  factory Homework.fromMap(Map<String, dynamic> map) {
    final rawTitle = (map['title'] as String?)?.trim();
    final rawLesson = (map['lesson'] as String?)?.trim();
    return Homework(
      id: map['id'].toString(),
      title: (rawTitle == null || rawTitle.isEmpty) ? 'واجب بدون عنوان' : rawTitle,
      lesson: (rawLesson == null || rawLesson.isEmpty) ? null : rawLesson,
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
    );
  }
}

class Submission {
  final String id;
  final String studentName;
  final String? studentEmail;
  final DateTime? submittedAt;

  const Submission({
    required this.id,
    required this.studentName,
    this.studentEmail,
    this.submittedAt,
  });

  factory Submission.fromMap(Map<String, dynamic> map) {
    // العلاقة قد ترجع Map أو List حسب إعدادات الـ Foreign Key
    final raw = map['students'];
    Map<String, dynamic>? student;
    if (raw is Map) {
      student = Map<String, dynamic>.from(raw);
    } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
      student = Map<String, dynamic>.from(raw.first as Map);
    }

    final name = (student?['full_name'] as String?)?.trim();
    final email = (student?['email'] as String?)?.trim();

    return Submission(
      id: map['id'].toString(),
      studentName: (name == null || name.isEmpty) ? 'طالب' : name,
      studentEmail: (email == null || email.isEmpty) ? null : email,
      submittedAt: DateTime.tryParse('${map['submitted_at'] ?? ''}'),
    );
  }
}

// ============================================================
// Helpers (Error handling + formatting)
// ============================================================

enum AppErrorKind { network, database, unknown }

AppErrorKind classifyError(Object e) {
  if (e is SocketException || e is TimeoutException || e is HttpException) {
    return AppErrorKind.network;
  }
  if (e is PostgrestException) return AppErrorKind.database;
  return AppErrorKind.unknown;
}

String errorMessage(AppErrorKind kind, String what) {
  switch (kind) {
    case AppErrorKind.network:
      return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى';
    case AppErrorKind.database:
      return 'حدث خطأ في قاعدة البيانات أثناء تحميل $what';
    case AppErrorKind.unknown:
      return 'حدث خطأ غير متوقع أثناء تحميل $what';
  }
}

void showErrorSnackBar(
  BuildContext context, {
  required AppErrorKind kind,
  required String message,
  required VoidCallback onRetry,
}) {
  final scheme = Theme.of(context).colorScheme;
  final icon = kind == AppErrorKind.network
      ? Icons.wifi_off_rounded
      : Icons.error_outline_rounded;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Icon(icon, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'إعادة المحاولة',
          textColor: scheme.error,
          onPressed: onRetry,
        ),
      ),
    );
}

String formatDateTime(DateTime? d) {
  if (d == null) return '-';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}/${two(l.month)}/${two(l.day)} - ${two(l.hour)}:${two(l.minute)}';
}

// ============================================================
// Shared widgets
// ============================================================

class StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
              ),
            ),
            child: Icon(icon, size: 56, color: scheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// يعرض حالة (فراغ / خطأ) داخل Scrollable ليعمل السحب للتحديث عليها أيضاً
class _ScrollableState extends StatelessWidget {
  final Widget child;
  const _ScrollableState({required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    );
  }
}

// ============================================================
// Screen 1: Homeworks list
// ============================================================

class TeacherHomeworksListScreen extends StatefulWidget {
  final String classId;
  const TeacherHomeworksListScreen({super.key, required this.classId});

  @override
  State<TeacherHomeworksListScreen> createState() =>
      _TeacherHomeworksListScreenState();
}

class _TeacherHomeworksListScreenState
    extends State<TeacherHomeworksListScreen> {
  List<Homework> _homeworks = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadHomeworks();
  }

  Future<void> _loadHomeworks() async {
    if (_homeworks.isEmpty) setState(() => _loading = true);

    try {
      final data = await supabase
          .from('homeworks')
          .select('id, title, lesson, created_at')
          .eq('class_id', widget.classId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _homeworks = (data as List)
            .map((e) => Homework.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      final kind = classifyError(e);
      setState(() {
        _loading = false;
        _hasError = _homeworks.isEmpty; // الخطأ الكامل فقط عند عدم وجود بيانات
      });
      showErrorSnackBar(
        context,
        kind: kind,
        message: errorMessage(kind, 'الواجبات'),
        onRetry: _loadHomeworks,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('واجبات الفصل ومتابعة الطلاب'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _loadHomeworks,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return _ScrollableState(
        child: StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'تعذر تحميل الواجبات',
          subtitle: 'تأكد من اتصالك بالإنترنت ثم حاول مرة أخرى',
          actionLabel: 'إعادة المحاولة',
          onAction: _loadHomeworks,
        ),
      );
    }

    if (_homeworks.isEmpty) {
      return const _ScrollableState(
        child: StateMessage(
          icon: Icons.assignment_outlined,
          title: 'لا توجد واجبات بعد',
          subtitle: 'لم تقم بإنشاء أي واجبات لهذه المرحلة حتى الآن.\nاسحب للأسفل للتحديث.',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _homeworks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _HomeworkCard(
        homework: _homeworks[index],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HomeworkSubmissionsScreen(
                homeworkId: _homeworks[index].id,
                homeworkTitle: _homeworks[index].title,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final Homework homework;
  final VoidCallback onTap;

  const _HomeworkCard({required this.homework, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [scheme.primaryContainer, scheme.surfaceContainerLow],
          ),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: scheme.onPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homework.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.bookmark_outline_rounded,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'الدرس: ${homework.lesson ?? '-'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            formatDateTime(homework.createdAt),
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Screen 2: Submissions
// ============================================================

class HomeworkSubmissionsScreen extends StatefulWidget {
  final String homeworkId;
  final String homeworkTitle;

  const HomeworkSubmissionsScreen({
    super.key,
    required this.homeworkId,
    required this.homeworkTitle,
  });

  @override
  State<HomeworkSubmissionsScreen> createState() =>
      _HomeworkSubmissionsScreenState();
}

class _HomeworkSubmissionsScreenState extends State<HomeworkSubmissionsScreen> {
  List<Submission> _submissions = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    if (_submissions.isEmpty) setState(() => _loading = true);

    try {
      final data = await supabase
          .from('submissions')
          .select('id, submitted_at, students(full_name, email)')
          .eq('homework_id', widget.homeworkId)
          .order('submitted_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _submissions = (data as List)
            .map((e) => Submission.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      final kind = classifyError(e);
      setState(() {
        _loading = false;
        _hasError = _submissions.isEmpty;
      });
      showErrorSnackBar(
        context,
        kind: kind,
        message: errorMessage(kind, 'تسليمات الطلاب'),
        onRetry: _loadSubmissions,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تسليمات: ${widget.homeworkTitle}'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _loadSubmissions,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return _ScrollableState(
        child: StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'تعذر تحميل التسليمات',
          subtitle: 'تأكد من اتصالك بالإنترنت ثم حاول مرة أخرى',
          actionLabel: 'إعادة المحاولة',
          onAction: _loadSubmissions,
        ),
      );
    }

    if (_submissions.isEmpty) {
      return const _ScrollableState(
        child: StateMessage(
          icon: Icons.inbox_outlined,
          title: 'لا توجد تسليمات بعد',
          subtitle: 'لم يقم أي طالب بتسليم هذا الواجب حتى الآن.\nاسحب للأسفل للتحديث.',
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _StatsCard(
              total: _submissions.length,
              lastSubmission: _submissions.first.submittedAt,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.separated(
            itemCount: _submissions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _SubmissionCard(submission: _submissions[index]),
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int total;
  final DateTime? lastSubmission;

  const _StatsCard({required this.total, required this.lastSubmission});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.how_to_reg_rounded,
                size: 32, color: scheme.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إجمالي الطلاب الذين سلّموا',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total',
                  style: text.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'آخر تسليم: ${formatDateTime(lastSubmission)}',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onPrimary.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final initial = submission.studentName.characters.first;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [scheme.secondaryContainer, scheme.surfaceContainerLow],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.secondary,
            child: Text(
              initial,
              style: TextStyle(
                color: scheme.onSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email_outlined,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        submission.studentEmail ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      formatDateTime(submission.submittedAt),
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 16, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'تم التسليم',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
