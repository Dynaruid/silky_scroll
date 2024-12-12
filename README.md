# Silky Scroll
`SilkyScroll` is a Flutter package that enhances the scrolling experience by adding smooth animations and customizable scroll physics for mobile, desktop, and web platforms.

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

## Custom Usage
```dart
class _ScrollExampleState extends State<ScrollExample> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final double offset = _scrollController.offset;
      print("scrollController offset is $offset");
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SilkyScroll(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            silkyScrollDuration: const Duration(milliseconds: 2000),
            direction: Axis.vertical,
            builder: (context, controller, physics) {
              return ListView.separated(
                scrollDirection: Axis.vertical,
                controller: controller,
                physics: physics,
                itemBuilder: (BuildContext context, int index) {
                  return ListItem(
                    height: 200,
                    number: index,
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return const Divider(
                    color: Colors.black45,
                  );
                },
                itemCount: 50,
              );
            }));
  }
}
```

