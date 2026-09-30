import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

const afghanJalaliMonths = <String>[
  'حمل',
  'ثور',
  'جوزا',
  'سرطان',
  'اسد',
  'سنبله',
  'میزان',
  'عقرب',
  'قوس',
  'جدی',
  'دلو',
  'حوت',
];

Future<Jalali?> showAfghanJalaliDatePicker(
  BuildContext context, {
  required Jalali initialDate,
  required Jalali firstDate,
  required Jalali lastDate,
}) => showDialog<Jalali>(
  context: context,
  builder: (_) => _AfghanDateDialog(
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

class _AfghanDateDialog extends StatefulWidget {
  const _AfghanDateDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final Jalali initialDate;
  final Jalali firstDate;
  final Jalali lastDate;

  @override
  State<_AfghanDateDialog> createState() => _AfghanDateDialogState();
}

class _AfghanDateDialogState extends State<_AfghanDateDialog> {
  late int year;
  late int month;
  late int day;

  @override
  void initState() {
    super.initState();
    year = widget.initialDate.year;
    month = widget.initialDate.month;
    day = widget.initialDate.day;
  }

  @override
  Widget build(BuildContext context) {
    final monthLength = Jalali(year, month, 1).monthLength;
    if (day > monthLength) {
      day = monthLength;
    }
    final years = [
      for (
        var value = widget.firstDate.year;
        value <= widget.lastDate.year;
        value++
      )
        value,
    ];
    return AlertDialog(
      title: const Text('انتخاب تاریخ'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(labelText: 'سال'),
                    items: years
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_digits(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => year = value!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'ماه'),
                    items: [
                      for (var value = 1; value <= 12; value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text(afghanJalaliMonths[value - 1]),
                        ),
                    ],
                    onChanged: (value) => setState(() => month = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _WeekdayLabel('ش'),
                _WeekdayLabel('ی'),
                _WeekdayLabel('د'),
                _WeekdayLabel('س'),
                _WeekdayLabel('چ'),
                _WeekdayLabel('پ'),
                _WeekdayLabel('ج'),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                mainAxisExtent: 36,
              ),
              itemCount: ((Jalali(year, month, 1).weekDay - 1) + monthLength),
              itemBuilder: (context, index) {
                final firstDayOffset = Jalali(year, month, 1).weekDay - 1;
                if (index < firstDayOffset) {
                  return const SizedBox.shrink();
                }
                final value = index - firstDayOffset + 1;
                final date = Jalali(year, month, value);
                final selectable =
                    date.compareTo(widget.firstDate) >= 0 &&
                    date.compareTo(widget.lastDate) <= 0;
                final selected = value == day;
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: selectable ? () => setState(() => day = value) : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: selected
                        ? const BoxDecoration(
                            color: Color(0xff3267ad),
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      _digits(value),
                      style: TextStyle(
                        color: !selectable
                            ? Colors.grey.shade400
                            : selected
                            ? Colors.white
                            : null,
                        fontWeight: selected ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('لغو'),
        ),
        FilledButton(
          onPressed: () {
            final value = Jalali(year, month, day);
            if (value.compareTo(widget.firstDate) < 0 ||
                value.compareTo(widget.lastDate) > 0) {
              return;
            }
            Navigator.pop(context, value);
          },
          child: const Text('تایید'),
        ),
      ],
    );
  }

  String _digits(int value) => value
      .toString()
      .split('')
      .map((digit) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(digit)])
      .join();
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 32,
    child: Center(
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

abstract final class JalaliDateUtils {
  static Jalali fromDateTime(DateTime date) => Jalali.fromDateTime(date);

  static String format(DateTime date) {
    final jalali = fromDateTime(date);
    return '${_digits(jalali.year)}/${_digits(jalali.month).padLeft(2, '۰')}/${_digits(jalali.day).padLeft(2, '۰')}';
  }

  static String _digits(int value) => value
      .toString()
      .split('')
      .map((digit) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(digit)])
      .join();
}
