import 'dart:convert';
import 'dart:js_interop';

import 'app_update.dart';

/// True when this browser exposes both a service worker container and the
/// Cache Storage API — i.e. there is actually something to clear.
///
/// Declared as a function (not a getter) to mirror `isAppUpdateSupported()` in
/// `app_update_web.dart`: external top-level members cannot be torn off.
@JS('naavisIsWebUpdateSupported')
external bool isAppUpdateSupported();

/// Bound to `clearServiceWorkerCaches()` in `web/app_update.js`. It resolves
/// to a JSON summary: `{unregistered, deleted, error}`.
@JS('naavisClearServiceWorkerCaches')
external JSPromise<JSString> _clearCaches();

/// Bound to `hardReload()` in `web/app_update.js`.
@JS('naavisHardReload')
external void _hardReload();

Future<AppUpdateOutcome> clearServiceWorkerCaches() async {
  try {
    final raw = await _clearCaches().toDart;
    final json = jsonDecode(raw.toDart) as Map<String, dynamic>;
    final error = json['error'] as String?;
    return AppUpdateOutcome(
      // `error: "unsupported"` is the shim telling us there was nothing to
      // clear, which is not a failure the user needs to act on.
      ok: error == null || error == 'unsupported',
      unregistered: (json['unregistered'] as num?)?.toInt() ?? 0,
      deleted: (json['deleted'] as num?)?.toInt() ?? 0,
      error: error == 'unsupported' ? null : error,
    );
  } catch (e) {
    return AppUpdateOutcome(ok: false, error: e.toString());
  }
}

void reload() => _hardReload();
