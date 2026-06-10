import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';

class POSKeyboardShortcuts {
  static KeyEventResult handleKeyEvent({
    required FocusNode keyboardFocusNode,
    required FocusNode searchFocusNode,
    required TextEditingController searchCtrl,
    required KeyEvent event,
    required VoidCallback onExit,
    required VoidCallback onPay,
    required VoidCallback onHold,
    required VoidCallback onUnhold,
    required VoidCallback onClearCart,
    required VoidCallback onAddCustomer,
    required VoidCallback onSwitchReturnMode,
    required VoidCallback onQuickAdd,
    required VoidCallback onAddDiscount,
    required VoidCallback onHistory,
    required VoidCallback onSwitchTheme,
    required void Function(String) onSearchSubmit,
    required void Function(String) onSearchUpdate,
  }) {
    final currentFocus = FocusManager.instance.primaryFocus;
    final isBackgroundOrSearch = currentFocus == keyboardFocusNode || currentFocus == searchFocusNode;

    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      
      // F-Keys and Escape are now handled globally via CallbackShortcuts generator methods
      // to forcefully suppress default operating system actions (Browser help, search, refresh, etc).

      // Actions that should ONLY trigger if the user isn't actively focused on another specific widget
      if (isBackgroundOrSearch) {
        if (key == LogicalKeyboardKey.enter) {
          if (searchCtrl.text.isNotEmpty) {
            onSearchSubmit(searchCtrl.text);
            return KeyEventResult.handled;
          } else {
            onPay();
            return KeyEventResult.handled;
          }
        }
        
        if (key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight) {
          if (HardwareKeyboard.instance.isControlPressed) {
            onUnhold();
          } else {
            onHold();
          }
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.f1) {
          onClearCart();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f2) {
          onAddCustomer();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f3) {
          onSwitchReturnMode();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f4) {
          onQuickAdd();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f5) {
          onAddDiscount();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f6) {
          onHistory();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f7) {
          onSwitchTheme();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.escape) {
          onExit();
          return KeyEventResult.handled;
        }

        if (event.character != null && event.character!.isNotEmpty) {
          if (!searchFocusNode.hasFocus) {
            searchFocusNode.requestFocus();
            searchCtrl.text += event.character!;
            searchCtrl.selection = TextSelection.collapsed(offset: searchCtrl.text.length);
            onSearchUpdate(searchCtrl.text);
            return KeyEventResult.handled;
          }
        }
      }
    }
    
    return KeyEventResult.ignored;
  }

  // ─── Binding Generators ─────────────────────────────────────────────

  static Map<ShortcutActivator, VoidCallback> getPosBindings({
    required VoidCallback onEscape,
    required VoidCallback onF1,
    required VoidCallback onF2,
    required VoidCallback onF3,
    required VoidCallback onF4,
    required VoidCallback onF5,
    required VoidCallback onF6,
    required VoidCallback onF7,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.escape): onEscape,
      const SingleActivator(LogicalKeyboardKey.f1): onF1,
      const SingleActivator(LogicalKeyboardKey.f2): onF2,
      const SingleActivator(LogicalKeyboardKey.f3): onF3,
      const SingleActivator(LogicalKeyboardKey.f4): onF4,
      const SingleActivator(LogicalKeyboardKey.f5): onF5,
      const SingleActivator(LogicalKeyboardKey.f6): onF6,
      const SingleActivator(LogicalKeyboardKey.f7): onF7,
    };
  }

  static Map<ShortcutActivator, VoidCallback> getPaymentBindings({
    required VoidCallback onEscape,
    required VoidCallback onF8,
    required VoidCallback onF9,
    required VoidCallback onF10,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.escape): onEscape,
      const SingleActivator(LogicalKeyboardKey.f8): onF8,
      const SingleActivator(LogicalKeyboardKey.f9): onF9,
      const SingleActivator(LogicalKeyboardKey.f10): onF10,
    };
  }

  static Map<ShortcutActivator, VoidCallback> getReceiptBindings({
    required VoidCallback onEscape,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.escape): onEscape,
    };
  }
}
