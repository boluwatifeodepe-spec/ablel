import 'package:hive/hive.dart';
import '../../core/utils/platform_utils.dart';

@HiveType(typeId: 0)
class DownloadRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String filePath;

  @HiveField(3)
  final String? thumbnail;

  @HiveField(4)
  final String platform;

  @HiveField(5)
  final int fileSize;

  @HiveField(6)
  final String duration;

  @HiveField(7)
  final String format; // 'mp4', 'mp3', etc.

  @HiveField(8)
  final String quality; // 'HD', 'SD', '320kbps'

  @HiveField(9)
  final DateTime downloadedAt;

  @HiveField(10)
  final String? originalUrl;

  DownloadRecord({
    required this.id,
    required this.title,
    required this.filePath,
    this.thumbnail,
    required this.platform,
    required this.fileSize,
    required this.duration,
    required this.format,
    required this.quality,
    required this.downloadedAt,
    this.originalUrl,
  });

  SocialPlatform get socialPlatform => SocialPlatform.fromString(platform);
  bool get isAudio => format.toLowerCase() == 'mp3' || format.toLowerCase() == 'm4a';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'thumbnail': thumbnail,
      'platform': platform,
      'fileSize': fileSize,
      'duration': duration,
      'format': format,
      'quality': quality,
      'downloadedAt': downloadedAt.toIso8601String(),
      'originalUrl': originalUrl,
    };
  }

  factory DownloadRecord.fromMap(Map<String, dynamic> map) {
    return DownloadRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      filePath: map['filePath'] as String,
      thumbnail: map['thumbnail'] as String?,
      platform: map['platform'] as String,
      fileSize: map['fileSize'] as int? ?? 0,
      duration: map['duration'] as String? ?? '00:00',
      format: map['format'] as String? ?? 'mp4',
      quality: map['quality'] as String? ?? 'HD',
      downloadedAt: map['downloadedAt'] != null 
          ? DateTime.parse(map['downloadedAt'] as String) 
          : DateTime.now(),
      originalUrl: map['originalUrl'] as String?,
    );
  }
}

/// Custom Hive Adapter for DownloadRecord without requiring code generation
class DownloadRecordAdapter extends TypeAdapter<DownloadRecord> {
  @override
  final int typeId = 0;

  @override
  DownloadRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadRecord(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      thumbnail: fields[3] as String?,
      platform: fields[4] as String,
      fileSize: fields[5] as int,
      duration: fields[6] as String,
      format: fields[7] as String,
      quality: fields[8] as String,
      downloadedAt: fields[9] as DateTime,
      originalUrl: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.thumbnail)
      ..writeByte(4)
      ..write(obj.platform)
      ..writeByte(5)
      ..write(obj.fileSize)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.format)
      ..writeByte(8)
      ..write(obj.quality)
      ..writeByte(9)
      ..write(obj.downloadedAt)
      ..writeByte(10)
      ..write(obj.originalUrl);
  }
}
