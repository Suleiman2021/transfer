import 'package:flutter/material.dart';

/// Returns an [onTap] callback that collapses any range-selection back to a
/// cursor at the tapped position.
///
/// On Android, tapping a focused text field while a cursor is visible can
/// extend the selection from the old cursor to the new tap position instead of
/// simply moving the cursor. This callback fixes that by collapsing to
/// [TextSelection.extentOffset] (the finger's new position) after each tap.
///
/// Usage:
///   TextFormField(
///     controller: _amount,
///     onTap: tapToMoveCursor(_amount),
///     ...
///   )
VoidCallback tapToMoveCursor(TextEditingController controller) {
  return () {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final sel = controller.selection;
        if (sel.isValid && !sel.isCollapsed) {
          controller.selection = TextSelection.collapsed(
            offset: sel.extentOffset,
          );
        }
      } catch (_) {
        // Controller disposed — nothing to do.
      }
    });
  };
}
