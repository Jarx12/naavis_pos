import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/exchange_rate.dart';

/// Aviso sutil de que la tasa de cambio local tiene más de 24 h (típico
/// escenario: cajero trabajando offline). No bloquea nada: los montos en
/// Bs. se calculan con la caché hasta que vuelva la red.
class RateStalenessChip extends ConsumerWidget {
  const RateStalenessChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateAsync = ref.watch(currentExchangeRateProvider);

    return rateAsync.when(
      data: (rate) {
        if (!rate.isStale) return const SizedBox.shrink();
        return Tooltip(
          message:
              'La tasa tiene ${DateTime.now().difference(rate.updatedAt).inHours} h '
              'sin actualizarse; se refrescará al volver la conexión.',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 12, color: Colors.amber),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Tasa desactualizada (${rate.updatedAt.day.toString().padLeft(2, '0')}/'
                  '${rate.updatedAt.month.toString().padLeft(2, '0')})',
                  style: const TextStyle(fontSize: 10, color: Colors.amber),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
      // Cargando o sin tasa: nada que avisar (el "Bs. --" ya lo indica).
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
