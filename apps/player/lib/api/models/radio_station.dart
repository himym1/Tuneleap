class RadioStation {
  final String id;
  final String name;
  final String streamUrl;
  final String? homePageUrl;

  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.homePageUrl,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      homePageUrl: json['homePageUrl'] as String?,
    );
  }
}
