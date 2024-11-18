# Silky Scroll
A wrapper for scrollable widgets that enables smooth scrolling with a mouse on all platforms.

First gif: Scrolling slowly.  
Second gif: Scrolling quickly (flick scroll).   
Third gif: Mobile drag scroll detected, physics change.  
<p float="left">
  <img src="https://raw.githubusercontent.com/Bluebar1/dyn_mouse_scroll/main/assets/slow_scroll.gif" width="200" height="350"/>
  <img src="https://raw.githubusercontent.com/Bluebar1/dyn_mouse_scroll/main/assets/fast_scroll.gif" width="200" height="350"/>
  <img src="https://raw.githubusercontent.com/Bluebar1/dyn_mouse_scroll/main/assets/drag_scroll.gif" width="200" height="350"/>
</p>

## Basic Usage
```dart
SilkyScroll(
  builder: (context, controller, physics) => ListView(
    controller: controller,
    physics: physics,
    children: ...
    )
)
```


