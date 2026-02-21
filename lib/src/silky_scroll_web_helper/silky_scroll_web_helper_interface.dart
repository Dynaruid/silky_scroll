/// Interface for platform-specific overscroll behavior management.
///
/// On web, this manipulates the HTML body's `overscroll-behavior-x`.
/// On other platforms, the implementation is a no-op.
abstract interface class SilkyScrollWebManagerInterface {
  /// Whether the current platform is web.
  bool get isWebPlatform;

  /// Temporarily blocks horizontal overscroll on the web.
  void blockOverscrollBehaviorXHtml();
}
