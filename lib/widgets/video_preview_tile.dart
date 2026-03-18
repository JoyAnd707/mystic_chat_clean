import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewTile extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;
  final double uiScale;

  const VideoPreviewTile({
    super.key,
    required this.videoUrl,
    required this.width,
    required this.height,
    required this.uiScale,
  });

  @override
  State<VideoPreviewTile> createState() => _VideoPreviewTileState();
}

class _VideoPreviewTileState extends State<VideoPreviewTile> {
  late final VideoPlayerController _c;
  Future<void>? _init;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _init = _c.initialize().then((_) async {
      if (!mounted) return;
      // ✅ חשוב: להשאיר על הפריים הראשון
      await _c.setLooping(false);
      await _c.pause();
      await _c.seekTo(Duration.zero);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.uiScale;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<void>(
        future: _init,
        builder: (context, snap) {
          final ready =
              snap.connectionState == ConnectionState.done && _c.value.isInitialized;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _c.value.size.width,
                    height: _c.value.size.height,
                    child: VideoPlayer(_c),
                  ),
                )
              else
                Container(color: Colors.black.withOpacity(0.25)),

              // ✅ Play overlay
              Center(
                child: Container(
                  width: 56 * s,
                  height: 56 * s,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 36 * s,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
