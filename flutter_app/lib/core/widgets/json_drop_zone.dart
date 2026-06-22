import 'package:flutter/widgets.dart';

import 'json_drop_zone_stub.dart'
    if (dart.library.html) 'json_drop_zone_web.dart' as impl;
import 'json_drop_zone_types.dart';

export 'json_drop_zone_types.dart';

class JsonDropZone extends StatelessWidget {
  const JsonDropZone({
    required this.onFileDropped,
    this.height = 128,
    super.key,
  });

  final ValueChanged<DroppedJsonFile> onFileDropped;
  final double height;

  @override
  Widget build(BuildContext context) {
    return impl.JsonDropZoneImpl(
      onFileDropped: onFileDropped,
      height: height,
    );
  }
}
