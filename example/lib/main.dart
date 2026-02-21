import 'package:flutter/material.dart';
import 'package:silky_scroll/silky_scroll.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scroll Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF132233)),
        useMaterial3: true,
      ),
      home: const ScrollExample(),
    );
  }
}

class ScrollExample extends StatefulWidget {
  const ScrollExample({super.key});

  @override
  State<ScrollExample> createState() => _ScrollExampleState();
}

class _ScrollExampleState extends State<ScrollExample> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final double offset = _scrollController.offset;
      debugPrint("scrollController offset is $offset");
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
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: SilkyScroll(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        silkyScrollDuration: const Duration(milliseconds: 2000),
        direction: Axis.vertical,
        builder: (context, controller, physics) {
          return ListView.separated(
            controller: controller,
            physics: physics,
            scrollDirection: Axis.vertical,
            itemBuilder: (BuildContext context, int index) {
              return InnerScrollingItem(height: 200, number: index);
            },
            separatorBuilder: (BuildContext context, int index) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                child: Divider(color: Colors.black45),
              );
            },
            itemCount: 50,
          );
        },
      ),
    );
  }
}

class InnerScrollingItem extends StatelessWidget {
  const InnerScrollingItem({
    super.key,
    required this.height,
    required this.number,
  });

  final double height;
  final int number;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: Card(
        color: Theme.of(context).colorScheme.onPrimary,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text("Test Item $number", style: const TextStyle(fontSize: 20)),
              Expanded(
                child: SilkyScroll(
                  builder: (context, controller, physics) {
                    return ListView.separated(
                      controller: controller,
                      physics: physics,
                      itemBuilder: (BuildContext context, int index) {
                        final Color color;
                        if (index % 2 == 0) {
                          color = Theme.of(
                            context,
                          ).colorScheme.secondaryContainer;
                        } else {
                          color = Theme.of(context).colorScheme.errorContainer;
                        }

                        return SizedBox(
                          height: 60,
                          child: Card(
                            elevation: 6,
                            margin: EdgeInsets.zero,
                            color: color,
                            child: Center(
                              child: Text(
                                "inner item number: $index",
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return const Divider(color: Colors.black45);
                      },
                      itemCount: 20,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
