import 'app_update.dart';

/// Non-web stub: there is no service worker or Cache Storage outside the web,
/// so there is nothing to refresh. Every other target is a no-op.
///
/// Mirrors the top-level signatures of `app_update_web.dart` (functions, not
/// getters, so the signatures match exactly).
bool isAppUpdateSupported() => false;

/// Always "unsupported" outside the web.
Future<AppUpdateOutcome> clearServiceWorkerCaches() async =>
    const AppUpdateOutcome.unsupported();

/// No-op outside the web.
void reload() {}

