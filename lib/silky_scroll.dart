/// Silky Scroll — smooth scrolling for Flutter.
///
/// Provides a [SilkyScroll] widget that wraps scrollable content
/// and delivers smooth, animated scrolling on all platforms.
library;

export 'src/silky_scroll_widget.dart'
    show SilkyScroll, SilkyScrollWidgetBuilder;
export 'src/silky_scroll_controller.dart'
    show SilkyScrollController, SilkyScrollPosition;
export 'src/blocked_scroll_physics.dart' show BlockedScrollPhysics;
export 'src/silky_scroll_config.dart' show SilkyScrollConfig;
export 'src/silky_scroll_state.dart' show ScrollPhysicsPhase;
