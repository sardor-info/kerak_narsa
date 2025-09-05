////////yandexxxx/////////
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as yandex;
import 'package:perfect_freehand/perfect_freehand.dart' as freehand;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FilledDrawMapPage(),
    );
  }
}

class FilledDrawMapPage extends StatefulWidget {
  const FilledDrawMapPage({super.key});

  @override
  State<FilledDrawMapPage> createState() => _FilledDrawMapPageState();
}

class _FilledDrawMapPageState extends State<FilledDrawMapPage> {
  yandex.YandexMapController? _controller;

  final yandex.Point _mapCenter =
  const yandex.Point(latitude: 41.3, longitude: 69.2);
  double _zoom = 14;

  final List<Stroke> lines = [];
  Stroke? _currentLine;

  final List<Offset> bubbles = [];

  freehand.StrokeOptions options = freehand.StrokeOptions(
    size: 4,
    thinning: 0.7,
    smoothing: 0.5,
    streamline: 0.5,
    simulatePressure: true,
  );

  bool canDraw = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateBubbles(MediaQuery.of(context).size);
    });
  }

  void _generateBubbles(Size size) {
    final rnd = Random();
    bubbles.clear();
    for (int i = 0; i < 500; i++) {
      bubbles.add(Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      ));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Realtime Draw on Map")),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: Stack(
          children: [
            // Xarita
            yandex.YandexMap(
              onMapCreated: (controller) async {
                _controller = controller;
                await controller.moveCamera(
                  yandex.CameraUpdate.newCameraPosition(
                    yandex.CameraPosition(target: _mapCenter, zoom: _zoom),
                  ),
                );
              },
            ),

            // Faqat chizish holatida gesture layer
            if (canDraw)
              Positioned.fill(
                child: Listener(
                  onPointerDown: canDraw ? _onPointerDown : null,
                  onPointerMove: canDraw ? _onPointerMove : null,
                  onPointerUp: canDraw ? _onPointerUp : null,
                  behavior: HitTestBehavior.translucent, // touch event pastga o‘tadi
                ),
              ),


            // Nuqtalar
            Positioned.fill(
              child: CustomPaint(
                painter: BubblePainter(bubbles),
              ),
            ),

            // Chizilgan chiziqlar
            Positioned.fill(
              child: CustomPaint(
                painter: StrokePainter(
                  color: Colors.blue,
                  lines: [...lines, if (_currentLine != null) _currentLine!],
                  options: options,
                ),
              ),
            ),
          ],
        )
        ,
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "startButton",
            onPressed: () {
              setState(() {
                canDraw = true;
                lines.clear();      // eski chiziqlarni o'chiramiz
                _currentLine = null;
                bubbles.clear();    // nuqtalarni o'chiramiz
              });
            },
            child: const Icon(Icons.brush),
            tooltip: "Start Drawing",
          ),

          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: "clearButton",
            onPressed: () {
              setState(() {
                lines.clear();
                _currentLine = null;
                bubbles.clear();
                _generateBubbles(MediaQuery.of(context).size);
                canDraw = false;
              });
            },
            child: const Icon(Icons.clear),
            tooltip: "Clear Drawing",
          ),
        ],
      ),
    );
  }

  void _onPointerDown(PointerDownEvent details) {
    if (!canDraw) return;
    final point =
    freehand.PointVector(details.localPosition.dx, details.localPosition.dy);
    setState(() {
      _currentLine = Stroke([point]);
      // bubbles.clear();  <-- bu satrni o'chiramiz, shuning uchun nuqtalar yo'qolmaydi
    });
  }


  void _onPointerMove(PointerMoveEvent details) {
    if (!canDraw || _currentLine == null) return;
    final point =
    freehand.PointVector(details.localPosition.dx, details.localPosition.dy);
    setState(() {
      _currentLine =
          _currentLine!.copyWith(points: [..._currentLine!.points, point]);
    });
  }

  void _onPointerUp(PointerUpEvent details) {
    if (!canDraw || _currentLine == null) return;

    setState(() {
      final closedLine = _currentLine!.copyWith(closed: true);
      lines
        ..clear()
        ..add(closedLine);

      final path = Path()
        ..moveTo(closedLine.points.first.dx, closedLine.points.first.dy);
      for (final p in closedLine.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();

      final rnd = Random();
      final size = MediaQuery.of(context).size;

      final newBubbles = <Offset>[];
      for (int i = 0; i < 500; i++) {
        final b = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
        if (path.contains(b)) newBubbles.add(b);
      }
      bubbles
        ..clear()
        ..addAll(newBubbles);

      _currentLine = null;
      canDraw = false;
    });
  }
}

class Stroke {
  final List<freehand.PointVector> points;
  final bool closed;
  const Stroke(this.points, {this.closed = false});

  Stroke copyWith({List<freehand.PointVector>? points, bool? closed}) {
    return Stroke(
      points ?? this.points,
      closed: closed ?? this.closed,
    );
  }
}

class StrokePainter extends CustomPainter {
  const StrokePainter({
    required this.color,
    required this.lines,
    required this.options,
  });

  final Color color;
  final List<Stroke> lines;
  final freehand.StrokeOptions options;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = options.size;

    for (final line in lines) {
      if (line.points.isEmpty) continue;

      if (line.points.length < 2) {
        final point = line.points.first;
        canvas.drawCircle(
            Offset(point.dx, point.dy), options.size / 2, fillPaint);
        continue;
      }

      final path =
      Path()..moveTo(line.points.first.dx, line.points.first.dy);
      for (int i = 1; i < line.points.length; i++) {
        path.lineTo(line.points[i].dx, line.points[i].dy);
      }

      if (line.closed) {
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      } else {
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) => true;
}

class BubblePainter extends CustomPainter {
  final List<Offset> bubbles;
  BubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random();
    for (final b in bubbles) {
      final paint = Paint()
        ..color =
        Colors.primaries[rnd.nextInt(Colors.primaries.length)].withOpacity(0.7);
      canvas.drawCircle(b, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) => true;
}



