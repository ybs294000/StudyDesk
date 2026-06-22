class DroppedJsonFile {
  const DroppedJsonFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final List<int> bytes;
}
