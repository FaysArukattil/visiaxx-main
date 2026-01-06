import 'package:flutter/material.dart';

/// A widget that provides group value and onChanged callback to its [RadioListTile] children.
/// This allows for cleaner code by avoiding passing groupValue and onChanged to every [RadioListTile].
class AppRadioGroup<T> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget child;

  const AppRadioGroup({
    super.key,
    this.groupValue,
    this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppRadioGroupProvider<T>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: child,
    );
  }

  static AppRadioGroupProvider<T>? of<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppRadioGroupProvider<T>>();
  }
}

class AppRadioGroupProvider<T> extends InheritedWidget {
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  const AppRadioGroupProvider({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required super.child,
  });

  @override
  bool updateShouldNotify(AppRadioGroupProvider<T> oldWidget) {
    return oldWidget.groupValue != groupValue ||
        oldWidget.onChanged != onChanged;
  }
}

/// A wrapper around [RadioListTile] that automatically uses the [AppRadioGroup] context if available.
class AppRadioListTile<T> extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final T value;
  final EdgeInsetsGeometry contentPadding;

  const AppRadioListTile({
    super.key,
    this.title,
    this.subtitle,
    required this.value,
    this.contentPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final groupProvider = AppRadioGroup.of<T>(context);

    return RadioListTile<T>(
      title: title,
      subtitle: subtitle,
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupProvider?.groupValue,
      // ignore: deprecated_member_use
      onChanged: groupProvider?.onChanged,
      contentPadding: contentPadding,
    );
  }
}
