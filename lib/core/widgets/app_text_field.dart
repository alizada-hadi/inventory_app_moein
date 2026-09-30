import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: keyboardType,
    obscureText: obscureText,
    textDirection: TextDirection.rtl,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefix,
      suffixIcon: suffix,
    ),
  );
}
