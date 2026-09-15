import 'package:flutter/services.dart';

/// Whether [value] is in an in-progress IME composition.
///
/// Windows (and some Linux IMEs) report a collapsed composing range such as
/// `0..0` when idle. That is not [TextRange.empty] (`-1..-1`), so a naive
/// `composing != TextRange.empty` check permanently blocks search.
bool isActivelyComposing(TextEditingValue value) {
  final range = value.composing;
  return range.isValid && !range.isCollapsed;
}
