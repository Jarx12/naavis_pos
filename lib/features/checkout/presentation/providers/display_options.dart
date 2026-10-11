import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opciones de visualización del grid del POS (persistidas en prefs):
///
/// - [showInvisible]: mostrar productos con `is_visible == false` (ocultos
///   en la tienda) con badge "OCULTO".
/// - [showOutOfStock]: mostrar productos sin ninguna variación con stock
///   con badge "AGOTADO".
///
/// Por defecto ambos apagados (mismo comportamiento que el server con
/// `only_visible=true` de siempre).
class DisplayOptions {
  final bool showInvisible;
  final bool showOutOfStock;

  const DisplayOptions({
    this.showInvisible = false,
    this.showOutOfStock = false,
  });

  DisplayOptions copyWith({bool? showInvisible, bool? showOutOfStock}) {
    return DisplayOptions(
      showInvisible: showInvisible ?? this.showInvisible,
      showOutOfStock: showOutOfStock ?? this.showOutOfStock,
    );
  }
}

const _kShowInvisible = 'pos_show_invisible';
const _kShowOutOfStock = 'pos_show_out_of_stock';

class DisplayOptionsNotifier extends Notifier<DisplayOptions> {
  /// true si el cajero ya tocó un toggle ANTES de que termine la carga
  /// inicial: en ese caso la carga no debe pisar su decisión.
  bool _dirty = false;

  @override
  DisplayOptions build() {
    Future.microtask(_load);
    return const DisplayOptions();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _dirty) return;
      state = DisplayOptions(
        showInvisible: prefs.getBool(_kShowInvisible) ?? false,
        showOutOfStock: prefs.getBool(_kShowOutOfStock) ?? false,
      );
    } catch (_) {
      // Sin prefs (entorno raro): se quedan los defaults.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kShowInvisible, state.showInvisible);
      await prefs.setBool(_kShowOutOfStock, state.showOutOfStock);
    } catch (_) {
      // Best-effort.
    }
  }

  void setShowInvisible(bool value) {
    _dirty = true;
    state = state.copyWith(showInvisible: value);
    _save();
  }

  void setShowOutOfStock(bool value) {
    _dirty = true;
    state = state.copyWith(showOutOfStock: value);
    _save();
  }
}

final displayOptionsProvider =
    NotifierProvider<DisplayOptionsNotifier, DisplayOptions>(
        DisplayOptionsNotifier.new);
