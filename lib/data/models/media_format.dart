class MediaFormat {
  final String id;
  final String label;
  final String quality;
  final String type; // 'video' or 'audio'
  final String ext; // 'mp4', 'mp3', etc.
  final String url;
  final int? filesize;
  final bool hasAudio;
  final bool noWatermark;

  const MediaFormat({
    required this.id,
    required this.label,
    required this.quality,
    required this.type,
    required this.ext,
    required this.url,
    this.filesize,
    this.hasAudio = true,
    this.noWatermark = true,
  });

  bool get isAudio => type == 'audio';
  bool get isVideo => type == 'video';

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    return MediaFormat(
      id: json['id'] as String? ?? 'format_${DateTime.now().millisecondsSinceEpoch}',
      label: json['label'] as String? ?? 'Standard',
      quality: json['quality'] as String? ?? '720p',
      type: json['type'] as String? ?? 'video',
      ext: json['ext'] as String? ?? 'mp4',
      url: json['url'] as String? ?? '',
      filesize: json['filesize'] as int?,
      hasAudio: json['hasAudio'] as bool? ?? true,
      noWatermark: json['noWatermark'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'quality': quality,
      'type': type,
      'ext': ext,
      'url': url,
      'filesize': filesize,
      'hasAudio': hasAudio,
      'noWatermark': noWatermark,
    };
  }
}
