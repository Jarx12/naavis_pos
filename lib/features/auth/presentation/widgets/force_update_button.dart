import 'package:flutter/material.dart';

import 'package:naavis_pos/core/platform/app_update.dart';

/// Botón de actualización forzada para la webapp instalada.
///
/// Una PWA queda cacheada por su service worker: al desplegar una versión
/// nueva, el dispositivo puede seguir sirviendo el bundle viejo y la app
/// parece "congelada". Este botón desregistra los service workers, borra el
/// Cache Storage y vuelve a cargar desde el servidor.
///
/// Solo se renderiza en la web (donde existe el service worker); en Android,
/// iOS nativo y escritorio [AppUpdate.isSupported] es false y el widget no
/// ocupa espacio.
class ForceUpdateButton extends StatefulWidget {
  const ForceUpdateButton({super.key});

  @override
  State<ForceUpdateButton> createState() => _ForceUpdateButtonState();
}

class _ForceUpdateButtonState extends State<ForceUpdateButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);

    // The reload below tears the page down, so the outcome is only surfaced
    // when something actually went wrong; on success the user never sees it.
    final outcome = await AppUpdate.clearServiceWorkerCaches();
    if (!mounted) return;

    if (!outcome.ok) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No se pudo limpiar la caché. Revisa tu conexión e inténtalo de nuevo.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    AppUpdate.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppUpdate.isSupported) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.center,
      child: TextButton.icon(
        onPressed: _busy ? null : _run,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.system_update_alt, size: 20),
        label: Text(_busy ? 'Actualizando…' : '¿Sigue igual? Forzar actualización'),
        style: TextButton.styleFrom(
          // Deliberately low-emphasis: a support escape hatch, not a
          // primary action on a POS screen.
          foregroundColor: Theme.of(context).colorScheme.outline,
          textStyle: const TextStyle(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
