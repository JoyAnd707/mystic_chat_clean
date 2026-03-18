import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoMessageTile extends StatefulWidget {
  final String url;
  final double uiScale;
  final double width;
  final double height;

  const VideoMessageTile({
    super.key,
    required this.url,
    required this.uiScale,
    required this.width,
    required this.height,
  });

  @override
  State<VideoMessageTile> createState() => _VideoMessageTileState();
}

class _VideoMessageTileState extends State<VideoMessageTile> {
  VideoPlayerController? _c;
  bool _loading = true;

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;

    try {
      await c.initialize();
      c.setLooping(true);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.uiScale;
    final c = _c;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRect(
        child: Material(
          color: Colors.black,
          child: InkWell(
            onTap: () {
              if (c == null || !c.value.isInitialized) return;
              if (c.value.isPlaying) {
                c.pause();
              } else {
                c.play();
              }
              if (mounted) setState(() {});
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (c != null && c.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                if (_loading)
                  SizedBox(
                    width: 22 * s,
                    height: 22 * s,
                    child: const CircularProgressIndicator(strokeWidth: 2.2),
                  ),

                if (!_loading && c != null && c.value.isInitialized)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: c.value.isPlaying ? 0.0 : 1.0,
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 44 * s,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
