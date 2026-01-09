/// Global state tracker for general app lifecycle and UI state.
/// Used for suppressing overlays during specific sequences like splash screens.
class AppStatus {
  static bool isSplashActive = false;
}
