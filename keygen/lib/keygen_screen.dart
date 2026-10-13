import 'dart:async';

import 'package:activation_key/activation_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'courses.dart';
import 'tokens.g.dart';

/// Длина ID-кода из приложения: 16 цифр Android ID + случайная цифра.
const _deviceCodeLength = 17;

/// ID-код ученика + курс → ключ, «Скопировать» и «Отправить».
class KeygenScreen extends StatefulWidget {
  const KeygenScreen({super.key});

  @override
  State<KeygenScreen> createState() => _KeygenScreenState();
}

class _KeygenScreenState extends State<KeygenScreen> {
  final _code = TextEditingController();
  Course? _course;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _copied = false));
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  String get _digits => _code.text;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) _code.text = digits;
  }

  String _message(Course course, String key) =>
      'Код активации курса «${course.title}»: $key\n'
      'В приложении: «Активировать курс» → поле «Код активации».';

  Future<void> _copy(String key) async {
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _send(Course course, String key) =>
      SharePlus.instance.share(ShareParams(text: _message(course, key)));

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final course = _course;
    final ready = _digits.isNotEmpty && course != null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.screen),
          children: [
            Text('Генератор ключей', style: AppText.screenTitle),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.sectionTitle.copyWith(letterSpacing: 1),
              decoration: InputDecoration(
                labelText: 'ID-код ученика',
                helperText:
                    _digits.isNotEmpty && _digits.length != _deviceCodeLength
                    ? 'В ID-коде из приложения $_deviceCodeLength цифр, '
                          'здесь ${_digits.length}. Всё ли скопировано?'
                    : null,
                helperStyle: AppText.caption.copyWith(color: c.danger),
                suffixIcon: _digits.isEmpty
                    ? IconButton(
                        tooltip: 'Вставить',
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste_rounded),
                      )
                    : IconButton(
                        tooltip: 'Очистить',
                        onPressed: _code.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'Курс',
              style: AppText.caption.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AppSpace.xs),
            Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              clipBehavior: Clip.antiAlias,
              child: RadioGroup<Course>(
                groupValue: course,
                onChanged: (v) => setState(() {
                  _course = v;
                  _copied = false;
                }),
                child: Column(
                  children: [
                    for (final item in courses)
                      RadioListTile<Course>(
                        value: item,
                        title: Text(item.title, style: AppText.lessonTitle),
                        secondary: Text(
                          '№ ${item.number}',
                          style: AppText.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (ready) ...[
              const SizedBox(height: AppSpace.md),
              _Result(
                code: _digits,
                course: course,
                copied: _copied,
                onCopy: _copy,
                onSend: _send,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.code,
    required this.course,
    required this.copied,
    required this.onCopy,
    required this.onSend,
  });

  final String code;
  final Course course;
  final bool copied;
  final ValueChanged<String> onCopy;
  final Future<void> Function(Course, String) onSend;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final key = expectedKey(code, course.number);
    final sum = weightedSum(code);
    final n = keyNumber(code, course.number);

    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ключ · ${course.title}',
            style: AppText.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpace.xs),
          SelectableText(
            key,
            style: AppText.screenTitle.copyWith(
              color: c.accent,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          // Расчёт — чтобы сверить с ручным.
          Text(
            'Сумма «цифра × место»: $sum\n'
            '$sum × (${course.number} + $keyCourseOffset) + $keySecret = $n',
            style: AppText.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpace.sm),
          FilledButton.icon(
            onPressed: () => onSend(course, key),
            icon: const Icon(Icons.send_rounded, size: 20),
            label: const Text('Отправить'),
          ),
          const SizedBox(height: AppSpace.xs),
          OutlinedButton.icon(
            onPressed: () => onCopy(key),
            icon: Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 20,
            ),
            label: Text(copied ? 'Скопировано' : 'Скопировать'),
          ),
        ],
      ),
    );
  }
}
