// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$SongsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
}
mixin _$LyricsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
  LyricsLines get lyricsLines => attachedDatabase.lyricsLines;
  LyricsWords get lyricsWords => attachedDatabase.lyricsWords;
}

class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
      'number', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _audioFilePathMeta =
      const VerificationMeta('audioFilePath');
  @override
  late final GeneratedColumn<String> audioFilePath = GeneratedColumn<String>(
      'audio_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDownloadedMeta =
      const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
      'is_downloaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_downloaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isFavoritedMeta =
      const VerificationMeta('isFavorited');
  @override
  late final GeneratedColumn<bool> isFavorited = GeneratedColumn<bool>(
      'is_favorited', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_favorited" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _hasSyncedLyricsMeta =
      const VerificationMeta('hasSyncedLyrics');
  @override
  late final GeneratedColumn<bool> hasSyncedLyrics = GeneratedColumn<bool>(
      'has_synced_lyrics', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("has_synced_lyrics" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastPlayedAtMeta =
      const VerificationMeta('lastPlayedAt');
  @override
  late final GeneratedColumn<String> lastPlayedAt = GeneratedColumn<String>(
      'last_played_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        number,
        title,
        durationMs,
        audioFilePath,
        isDownloaded,
        isFavorited,
        hasSyncedLyrics,
        lastPlayedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(Insertable<Song> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('audio_file_path')) {
      context.handle(
          _audioFilePathMeta,
          audioFilePath.isAcceptableOrUnknown(
              data['audio_file_path']!, _audioFilePathMeta));
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    if (data.containsKey('is_favorited')) {
      context.handle(
          _isFavoritedMeta,
          isFavorited.isAcceptableOrUnknown(
              data['is_favorited']!, _isFavoritedMeta));
    }
    if (data.containsKey('has_synced_lyrics')) {
      context.handle(
          _hasSyncedLyricsMeta,
          hasSyncedLyrics.isAcceptableOrUnknown(
              data['has_synced_lyrics']!, _hasSyncedLyricsMeta));
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
          _lastPlayedAtMeta,
          lastPlayedAt.isAcceptableOrUnknown(
              data['last_played_at']!, _lastPlayedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}number'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      audioFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_file_path']),
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      isFavorited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorited'])!,
      hasSyncedLyrics: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}has_synced_lyrics'])!,
      lastPlayedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_played_at']),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  /// Internal auto-increment PK. Use [number] for domain identity.
  final int id;

  /// Official positive song number. Unique and indexed.
  final int number;

  /// Official song title (e.g. "Jehovah Is Your Name").
  final String title;

  /// Total audio duration in milliseconds. Nullable until audio is analysed.
  final int? durationMs;

  /// Absolute path to the cached audio file on the device filesystem.
  /// Null means the audio has not been downloaded on this device.
  final String? audioFilePath;

  /// True once the audio file has been written to local storage.
  final bool isDownloaded;

  /// Whether the user has hearted this song.
  final bool isFavorited;

  /// Whether an .elrc file exists for this song (drives UI "synced" badge).
  final bool hasSyncedLyrics;

  /// ISO-8601 timestamp of the last time the user played this song.
  final String? lastPlayedAt;
  const Song(
      {required this.id,
      required this.number,
      required this.title,
      this.durationMs,
      this.audioFilePath,
      required this.isDownloaded,
      required this.isFavorited,
      required this.hasSyncedLyrics,
      this.lastPlayedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['number'] = Variable<int>(number);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || audioFilePath != null) {
      map['audio_file_path'] = Variable<String>(audioFilePath);
    }
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    map['is_favorited'] = Variable<bool>(isFavorited);
    map['has_synced_lyrics'] = Variable<bool>(hasSyncedLyrics);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<String>(lastPlayedAt);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      number: Value(number),
      title: Value(title),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      audioFilePath: audioFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFilePath),
      isDownloaded: Value(isDownloaded),
      isFavorited: Value(isFavorited),
      hasSyncedLyrics: Value(hasSyncedLyrics),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
    );
  }

  factory Song.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<int>(json['id']),
      number: serializer.fromJson<int>(json['number']),
      title: serializer.fromJson<String>(json['title']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      audioFilePath: serializer.fromJson<String?>(json['audioFilePath']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      isFavorited: serializer.fromJson<bool>(json['isFavorited']),
      hasSyncedLyrics: serializer.fromJson<bool>(json['hasSyncedLyrics']),
      lastPlayedAt: serializer.fromJson<String?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'number': serializer.toJson<int>(number),
      'title': serializer.toJson<String>(title),
      'durationMs': serializer.toJson<int?>(durationMs),
      'audioFilePath': serializer.toJson<String?>(audioFilePath),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'isFavorited': serializer.toJson<bool>(isFavorited),
      'hasSyncedLyrics': serializer.toJson<bool>(hasSyncedLyrics),
      'lastPlayedAt': serializer.toJson<String?>(lastPlayedAt),
    };
  }

  Song copyWith(
          {int? id,
          int? number,
          String? title,
          Value<int?> durationMs = const Value.absent(),
          Value<String?> audioFilePath = const Value.absent(),
          bool? isDownloaded,
          bool? isFavorited,
          bool? hasSyncedLyrics,
          Value<String?> lastPlayedAt = const Value.absent()}) =>
      Song(
        id: id ?? this.id,
        number: number ?? this.number,
        title: title ?? this.title,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        audioFilePath:
            audioFilePath.present ? audioFilePath.value : this.audioFilePath,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        isFavorited: isFavorited ?? this.isFavorited,
        hasSyncedLyrics: hasSyncedLyrics ?? this.hasSyncedLyrics,
        lastPlayedAt:
            lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
      );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      id: data.id.present ? data.id.value : this.id,
      number: data.number.present ? data.number.value : this.number,
      title: data.title.present ? data.title.value : this.title,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      audioFilePath: data.audioFilePath.present
          ? data.audioFilePath.value
          : this.audioFilePath,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      isFavorited:
          data.isFavorited.present ? data.isFavorited.value : this.isFavorited,
      hasSyncedLyrics: data.hasSyncedLyrics.present
          ? data.hasSyncedLyrics.value
          : this.hasSyncedLyrics,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isFavorited: $isFavorited, ')
          ..write('hasSyncedLyrics: $hasSyncedLyrics, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, number, title, durationMs, audioFilePath,
      isDownloaded, isFavorited, hasSyncedLyrics, lastPlayedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.id == this.id &&
          other.number == this.number &&
          other.title == this.title &&
          other.durationMs == this.durationMs &&
          other.audioFilePath == this.audioFilePath &&
          other.isDownloaded == this.isDownloaded &&
          other.isFavorited == this.isFavorited &&
          other.hasSyncedLyrics == this.hasSyncedLyrics &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<int> id;
  final Value<int> number;
  final Value<String> title;
  final Value<int?> durationMs;
  final Value<String?> audioFilePath;
  final Value<bool> isDownloaded;
  final Value<bool> isFavorited;
  final Value<bool> hasSyncedLyrics;
  final Value<String?> lastPlayedAt;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.number = const Value.absent(),
    this.title = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.isFavorited = const Value.absent(),
    this.hasSyncedLyrics = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
  });
  SongsCompanion.insert({
    this.id = const Value.absent(),
    required int number,
    required String title,
    this.durationMs = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.isFavorited = const Value.absent(),
    this.hasSyncedLyrics = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
  })  : number = Value(number),
        title = Value(title);
  static Insertable<Song> custom({
    Expression<int>? id,
    Expression<int>? number,
    Expression<String>? title,
    Expression<int>? durationMs,
    Expression<String>? audioFilePath,
    Expression<bool>? isDownloaded,
    Expression<bool>? isFavorited,
    Expression<bool>? hasSyncedLyrics,
    Expression<String>? lastPlayedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (number != null) 'number': number,
      if (title != null) 'title': title,
      if (durationMs != null) 'duration_ms': durationMs,
      if (audioFilePath != null) 'audio_file_path': audioFilePath,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (isFavorited != null) 'is_favorited': isFavorited,
      if (hasSyncedLyrics != null) 'has_synced_lyrics': hasSyncedLyrics,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
    });
  }

  SongsCompanion copyWith(
      {Value<int>? id,
      Value<int>? number,
      Value<String>? title,
      Value<int?>? durationMs,
      Value<String?>? audioFilePath,
      Value<bool>? isDownloaded,
      Value<bool>? isFavorited,
      Value<bool>? hasSyncedLyrics,
      Value<String?>? lastPlayedAt}) {
    return SongsCompanion(
      id: id ?? this.id,
      number: number ?? this.number,
      title: title ?? this.title,
      durationMs: durationMs ?? this.durationMs,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isFavorited: isFavorited ?? this.isFavorited,
      hasSyncedLyrics: hasSyncedLyrics ?? this.hasSyncedLyrics,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (audioFilePath.present) {
      map['audio_file_path'] = Variable<String>(audioFilePath.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (isFavorited.present) {
      map['is_favorited'] = Variable<bool>(isFavorited.value);
    }
    if (hasSyncedLyrics.present) {
      map['has_synced_lyrics'] = Variable<bool>(hasSyncedLyrics.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<String>(lastPlayedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('isFavorited: $isFavorited, ')
          ..write('hasSyncedLyrics: $hasSyncedLyrics, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }
}

class LyricsLines extends Table with TableInfo<LyricsLines, LyricsLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LyricsLines(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'PRIMARY KEY AUTOINCREMENT NOT NULL');
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
      'song_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES songs(id)ON DELETE CASCADE');
  static const VerificationMeta _lineIndexMeta =
      const VerificationMeta('lineIndex');
  late final GeneratedColumn<int> lineIndex = GeneratedColumn<int>(
      'line_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _sectionIndexMeta =
      const VerificationMeta('sectionIndex');
  late final GeneratedColumn<int> sectionIndex = GeneratedColumn<int>(
      'section_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _startMsMeta =
      const VerificationMeta('startMs');
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
      'start_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
      'end_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _lineTextMeta =
      const VerificationMeta('lineText');
  late final GeneratedColumn<String> lineText = GeneratedColumn<String>(
      'text', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [id, songId, lineIndex, sectionIndex, startMs, endMs, lineText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_lines';
  @override
  VerificationContext validateIntegrity(Insertable<LyricsLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('line_index')) {
      context.handle(_lineIndexMeta,
          lineIndex.isAcceptableOrUnknown(data['line_index']!, _lineIndexMeta));
    } else if (isInserting) {
      context.missing(_lineIndexMeta);
    }
    if (data.containsKey('section_index')) {
      context.handle(
          _sectionIndexMeta,
          sectionIndex.isAcceptableOrUnknown(
              data['section_index']!, _sectionIndexMeta));
    }
    if (data.containsKey('start_ms')) {
      context.handle(_startMsMeta,
          startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta));
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
          _endMsMeta, endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta));
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('text')) {
      context.handle(_lineTextMeta,
          lineText.isAcceptableOrUnknown(data['text']!, _lineTextMeta));
    } else if (isInserting) {
      context.missing(_lineTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {songId, lineIndex},
      ];
  @override
  LyricsLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsLine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      lineIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}line_index'])!,
      sectionIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}section_index'])!,
      startMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_ms'])!,
      endMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_ms'])!,
      lineText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text'])!,
    );
  }

  @override
  LyricsLines createAlias(String alias) {
    return LyricsLines(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(song_id, line_index)'];
  @override
  bool get dontWriteConstraints => true;
}

class LyricsLine extends DataClass implements Insertable<LyricsLine> {
  final int id;
  final int songId;
  final int lineIndex;
  final int sectionIndex;
  final int startMs;
  final int endMs;
  final String lineText;
  const LyricsLine(
      {required this.id,
      required this.songId,
      required this.lineIndex,
      required this.sectionIndex,
      required this.startMs,
      required this.endMs,
      required this.lineText});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<int>(songId);
    map['line_index'] = Variable<int>(lineIndex);
    map['section_index'] = Variable<int>(sectionIndex);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['text'] = Variable<String>(lineText);
    return map;
  }

  LyricsLinesCompanion toCompanion(bool nullToAbsent) {
    return LyricsLinesCompanion(
      id: Value(id),
      songId: Value(songId),
      lineIndex: Value(lineIndex),
      sectionIndex: Value(sectionIndex),
      startMs: Value(startMs),
      endMs: Value(endMs),
      lineText: Value(lineText),
    );
  }

  factory LyricsLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsLine(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<int>(json['song_id']),
      lineIndex: serializer.fromJson<int>(json['line_index']),
      sectionIndex: serializer.fromJson<int>(json['section_index']),
      startMs: serializer.fromJson<int>(json['start_ms']),
      endMs: serializer.fromJson<int>(json['end_ms']),
      lineText: serializer.fromJson<String>(json['text']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'song_id': serializer.toJson<int>(songId),
      'line_index': serializer.toJson<int>(lineIndex),
      'section_index': serializer.toJson<int>(sectionIndex),
      'start_ms': serializer.toJson<int>(startMs),
      'end_ms': serializer.toJson<int>(endMs),
      'text': serializer.toJson<String>(lineText),
    };
  }

  LyricsLine copyWith(
          {int? id,
          int? songId,
          int? lineIndex,
          int? sectionIndex,
          int? startMs,
          int? endMs,
          String? lineText}) =>
      LyricsLine(
        id: id ?? this.id,
        songId: songId ?? this.songId,
        lineIndex: lineIndex ?? this.lineIndex,
        sectionIndex: sectionIndex ?? this.sectionIndex,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        lineText: lineText ?? this.lineText,
      );
  LyricsLine copyWithCompanion(LyricsLinesCompanion data) {
    return LyricsLine(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      lineIndex: data.lineIndex.present ? data.lineIndex.value : this.lineIndex,
      sectionIndex: data.sectionIndex.present
          ? data.sectionIndex.value
          : this.sectionIndex,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      lineText: data.lineText.present ? data.lineText.value : this.lineText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsLine(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('lineIndex: $lineIndex, ')
          ..write('sectionIndex: $sectionIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('lineText: $lineText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, songId, lineIndex, sectionIndex, startMs, endMs, lineText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsLine &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.lineIndex == this.lineIndex &&
          other.sectionIndex == this.sectionIndex &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.lineText == this.lineText);
}

class LyricsLinesCompanion extends UpdateCompanion<LyricsLine> {
  final Value<int> id;
  final Value<int> songId;
  final Value<int> lineIndex;
  final Value<int> sectionIndex;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> lineText;
  const LyricsLinesCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.lineIndex = const Value.absent(),
    this.sectionIndex = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.lineText = const Value.absent(),
  });
  LyricsLinesCompanion.insert({
    this.id = const Value.absent(),
    required int songId,
    required int lineIndex,
    this.sectionIndex = const Value.absent(),
    required int startMs,
    required int endMs,
    required String lineText,
  })  : songId = Value(songId),
        lineIndex = Value(lineIndex),
        startMs = Value(startMs),
        endMs = Value(endMs),
        lineText = Value(lineText);
  static Insertable<LyricsLine> custom({
    Expression<int>? id,
    Expression<int>? songId,
    Expression<int>? lineIndex,
    Expression<int>? sectionIndex,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? lineText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (lineIndex != null) 'line_index': lineIndex,
      if (sectionIndex != null) 'section_index': sectionIndex,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (lineText != null) 'text': lineText,
    });
  }

  LyricsLinesCompanion copyWith(
      {Value<int>? id,
      Value<int>? songId,
      Value<int>? lineIndex,
      Value<int>? sectionIndex,
      Value<int>? startMs,
      Value<int>? endMs,
      Value<String>? lineText}) {
    return LyricsLinesCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      lineIndex: lineIndex ?? this.lineIndex,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      lineText: lineText ?? this.lineText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (lineIndex.present) {
      map['line_index'] = Variable<int>(lineIndex.value);
    }
    if (sectionIndex.present) {
      map['section_index'] = Variable<int>(sectionIndex.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (lineText.present) {
      map['text'] = Variable<String>(lineText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsLinesCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('lineIndex: $lineIndex, ')
          ..write('sectionIndex: $sectionIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('lineText: $lineText')
          ..write(')'))
        .toString();
  }
}

class LyricsWords extends Table with TableInfo<LyricsWords, LyricsWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LyricsWords(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'PRIMARY KEY AUTOINCREMENT NOT NULL');
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  late final GeneratedColumn<int> lineId = GeneratedColumn<int>(
      'line_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL REFERENCES lyrics_lines(id)ON DELETE CASCADE');
  static const VerificationMeta _wordIndexMeta =
      const VerificationMeta('wordIndex');
  late final GeneratedColumn<int> wordIndex = GeneratedColumn<int>(
      'word_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _startMsMeta =
      const VerificationMeta('startMs');
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
      'start_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
      'end_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _wordTextMeta =
      const VerificationMeta('wordText');
  late final GeneratedColumn<String> wordText = GeneratedColumn<String>(
      'text', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [id, lineId, wordIndex, startMs, endMs, wordText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_words';
  @override
  VerificationContext validateIntegrity(Insertable<LyricsWord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('line_id')) {
      context.handle(_lineIdMeta,
          lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta));
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('word_index')) {
      context.handle(_wordIndexMeta,
          wordIndex.isAcceptableOrUnknown(data['word_index']!, _wordIndexMeta));
    } else if (isInserting) {
      context.missing(_wordIndexMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(_startMsMeta,
          startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta));
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
          _endMsMeta, endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta));
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('text')) {
      context.handle(_wordTextMeta,
          wordText.isAcceptableOrUnknown(data['text']!, _wordTextMeta));
    } else if (isInserting) {
      context.missing(_wordTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {lineId, wordIndex},
      ];
  @override
  LyricsWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsWord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      lineId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}line_id'])!,
      wordIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}word_index'])!,
      startMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_ms'])!,
      endMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_ms'])!,
      wordText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text'])!,
    );
  }

  @override
  LyricsWords createAlias(String alias) {
    return LyricsWords(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(line_id, word_index)'];
  @override
  bool get dontWriteConstraints => true;
}

class LyricsWord extends DataClass implements Insertable<LyricsWord> {
  final int id;
  final int lineId;
  final int wordIndex;
  final int startMs;
  final int endMs;
  final String wordText;
  const LyricsWord(
      {required this.id,
      required this.lineId,
      required this.wordIndex,
      required this.startMs,
      required this.endMs,
      required this.wordText});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['line_id'] = Variable<int>(lineId);
    map['word_index'] = Variable<int>(wordIndex);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['text'] = Variable<String>(wordText);
    return map;
  }

  LyricsWordsCompanion toCompanion(bool nullToAbsent) {
    return LyricsWordsCompanion(
      id: Value(id),
      lineId: Value(lineId),
      wordIndex: Value(wordIndex),
      startMs: Value(startMs),
      endMs: Value(endMs),
      wordText: Value(wordText),
    );
  }

  factory LyricsWord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsWord(
      id: serializer.fromJson<int>(json['id']),
      lineId: serializer.fromJson<int>(json['line_id']),
      wordIndex: serializer.fromJson<int>(json['word_index']),
      startMs: serializer.fromJson<int>(json['start_ms']),
      endMs: serializer.fromJson<int>(json['end_ms']),
      wordText: serializer.fromJson<String>(json['text']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'line_id': serializer.toJson<int>(lineId),
      'word_index': serializer.toJson<int>(wordIndex),
      'start_ms': serializer.toJson<int>(startMs),
      'end_ms': serializer.toJson<int>(endMs),
      'text': serializer.toJson<String>(wordText),
    };
  }

  LyricsWord copyWith(
          {int? id,
          int? lineId,
          int? wordIndex,
          int? startMs,
          int? endMs,
          String? wordText}) =>
      LyricsWord(
        id: id ?? this.id,
        lineId: lineId ?? this.lineId,
        wordIndex: wordIndex ?? this.wordIndex,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        wordText: wordText ?? this.wordText,
      );
  LyricsWord copyWithCompanion(LyricsWordsCompanion data) {
    return LyricsWord(
      id: data.id.present ? data.id.value : this.id,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      wordIndex: data.wordIndex.present ? data.wordIndex.value : this.wordIndex,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      wordText: data.wordText.present ? data.wordText.value : this.wordText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsWord(')
          ..write('id: $id, ')
          ..write('lineId: $lineId, ')
          ..write('wordIndex: $wordIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('wordText: $wordText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lineId, wordIndex, startMs, endMs, wordText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsWord &&
          other.id == this.id &&
          other.lineId == this.lineId &&
          other.wordIndex == this.wordIndex &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.wordText == this.wordText);
}

class LyricsWordsCompanion extends UpdateCompanion<LyricsWord> {
  final Value<int> id;
  final Value<int> lineId;
  final Value<int> wordIndex;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> wordText;
  const LyricsWordsCompanion({
    this.id = const Value.absent(),
    this.lineId = const Value.absent(),
    this.wordIndex = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.wordText = const Value.absent(),
  });
  LyricsWordsCompanion.insert({
    this.id = const Value.absent(),
    required int lineId,
    required int wordIndex,
    required int startMs,
    required int endMs,
    required String wordText,
  })  : lineId = Value(lineId),
        wordIndex = Value(wordIndex),
        startMs = Value(startMs),
        endMs = Value(endMs),
        wordText = Value(wordText);
  static Insertable<LyricsWord> custom({
    Expression<int>? id,
    Expression<int>? lineId,
    Expression<int>? wordIndex,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? wordText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lineId != null) 'line_id': lineId,
      if (wordIndex != null) 'word_index': wordIndex,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (wordText != null) 'text': wordText,
    });
  }

  LyricsWordsCompanion copyWith(
      {Value<int>? id,
      Value<int>? lineId,
      Value<int>? wordIndex,
      Value<int>? startMs,
      Value<int>? endMs,
      Value<String>? wordText}) {
    return LyricsWordsCompanion(
      id: id ?? this.id,
      lineId: lineId ?? this.lineId,
      wordIndex: wordIndex ?? this.wordIndex,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      wordText: wordText ?? this.wordText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<int>(lineId.value);
    }
    if (wordIndex.present) {
      map['word_index'] = Variable<int>(wordIndex.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (wordText.present) {
      map['text'] = Variable<String>(wordText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsWordsCompanion(')
          ..write('id: $id, ')
          ..write('lineId: $lineId, ')
          ..write('wordIndex: $wordIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('wordText: $wordText')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 80),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(Insertable<Playlist> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  const Playlist({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Playlist copyWith({int? id, String? name}) => Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
      );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist && other.id == this.id && other.name == this.name);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  PlaylistsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $PlaylistEntriesTable extends PlaylistEntries
    with TableInfo<$PlaylistEntriesTable, PlaylistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES playlists (id) ON DELETE CASCADE'));
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
      'song_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES songs (id) ON DELETE CASCADE'));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [playlistId, songId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_entries';
  @override
  VerificationContext validateIntegrity(Insertable<PlaylistEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, songId};
  @override
  PlaylistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEntry(
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}playlist_id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $PlaylistEntriesTable createAlias(String alias) {
    return $PlaylistEntriesTable(attachedDatabase, alias);
  }
}

class PlaylistEntry extends DataClass implements Insertable<PlaylistEntry> {
  final int playlistId;
  final int songId;
  final int position;
  const PlaylistEntry(
      {required this.playlistId, required this.songId, required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['song_id'] = Variable<int>(songId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistEntriesCompanion(
      playlistId: Value(playlistId),
      songId: Value(songId),
      position: Value(position),
    );
  }

  factory PlaylistEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistEntry(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      songId: serializer.fromJson<int>(json['songId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'songId': serializer.toJson<int>(songId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistEntry copyWith({int? playlistId, int? songId, int? position}) =>
      PlaylistEntry(
        playlistId: playlistId ?? this.playlistId,
        songId: songId ?? this.songId,
        position: position ?? this.position,
      );
  PlaylistEntry copyWithCompanion(PlaylistEntriesCompanion data) {
    return PlaylistEntry(
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      songId: data.songId.present ? data.songId.value : this.songId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntry(')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, songId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistEntry &&
          other.playlistId == this.playlistId &&
          other.songId == this.songId &&
          other.position == this.position);
}

class PlaylistEntriesCompanion extends UpdateCompanion<PlaylistEntry> {
  final Value<int> playlistId;
  final Value<int> songId;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistEntriesCompanion({
    this.playlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistEntriesCompanion.insert({
    required int playlistId,
    required int songId,
    required int position,
    this.rowid = const Value.absent(),
  })  : playlistId = Value(playlistId),
        songId = Value(songId),
        position = Value(position);
  static Insertable<PlaylistEntry> custom({
    Expression<int>? playlistId,
    Expression<int>? songId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (songId != null) 'song_id': songId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistEntriesCompanion copyWith(
      {Value<int>? playlistId,
      Value<int>? songId,
      Value<int>? position,
      Value<int>? rowid}) {
    return PlaylistEntriesCompanion(
      playlistId: playlistId ?? this.playlistId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntriesCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SongsTable songs = $SongsTable(this);
  late final LyricsLines lyricsLines = LyricsLines(this);
  late final LyricsWords lyricsWords = LyricsWords(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistEntriesTable playlistEntries =
      $PlaylistEntriesTable(this);
  late final SongsDao songsDao = SongsDao(this as AppDatabase);
  late final LyricsDao lyricsDao = LyricsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [songs, lyricsLines, lyricsWords, playlists, playlistEntries];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('songs',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('lyrics_lines', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('lyrics_lines',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('lyrics_words', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('playlists',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('playlist_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('songs',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('playlist_entries', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$SongsTableCreateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  required int number,
  required String title,
  Value<int?> durationMs,
  Value<String?> audioFilePath,
  Value<bool> isDownloaded,
  Value<bool> isFavorited,
  Value<bool> hasSyncedLyrics,
  Value<String?> lastPlayedAt,
});
typedef $$SongsTableUpdateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  Value<int> number,
  Value<String> title,
  Value<int?> durationMs,
  Value<String?> audioFilePath,
  Value<bool> isDownloaded,
  Value<bool> isFavorited,
  Value<bool> hasSyncedLyrics,
  Value<String?> lastPlayedAt,
});

final class $$SongsTableReferences
    extends BaseReferences<_$AppDatabase, $SongsTable, Song> {
  $$SongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<LyricsLines, List<LyricsLine>>
      _lyricsLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.lyricsLines,
          aliasName: $_aliasNameGenerator(db.songs.id, db.lyricsLines.songId));

  $LyricsLinesProcessedTableManager get lyricsLinesRefs {
    final manager = $LyricsLinesTableManager($_db, $_db.lyricsLines)
        .filter((f) => f.songId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lyricsLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PlaylistEntriesTable, List<PlaylistEntry>>
      _playlistEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playlistEntries,
              aliasName:
                  $_aliasNameGenerator(db.songs.id, db.playlistEntries.songId));

  $$PlaylistEntriesTableProcessedTableManager get playlistEntriesRefs {
    final manager =
        $$PlaylistEntriesTableTableManager($_db, $_db.playlistEntries)
            .filter((f) => f.songId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_playlistEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorited => $composableBuilder(
      column: $table.isFavorited, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasSyncedLyrics => $composableBuilder(
      column: $table.hasSyncedLyrics,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> lyricsLinesRefs(
      Expression<bool> Function($LyricsLinesFilterComposer f) f) {
    final $LyricsLinesFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lyricsLines,
        getReferencedColumn: (t) => t.songId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $LyricsLinesFilterComposer(
              $db: $db,
              $table: $db.lyricsLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> playlistEntriesRefs(
      Expression<bool> Function($$PlaylistEntriesTableFilterComposer f) f) {
    final $$PlaylistEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistEntries,
        getReferencedColumn: (t) => t.songId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistEntriesTableFilterComposer(
              $db: $db,
              $table: $db.playlistEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorited => $composableBuilder(
      column: $table.isFavorited, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasSyncedLyrics => $composableBuilder(
      column: $table.hasSyncedLyrics,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<bool> get isFavorited => $composableBuilder(
      column: $table.isFavorited, builder: (column) => column);

  GeneratedColumn<bool> get hasSyncedLyrics => $composableBuilder(
      column: $table.hasSyncedLyrics, builder: (column) => column);

  GeneratedColumn<String> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => column);

  Expression<T> lyricsLinesRefs<T extends Object>(
      Expression<T> Function($LyricsLinesAnnotationComposer a) f) {
    final $LyricsLinesAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lyricsLines,
        getReferencedColumn: (t) => t.songId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $LyricsLinesAnnotationComposer(
              $db: $db,
              $table: $db.lyricsLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> playlistEntriesRefs<T extends Object>(
      Expression<T> Function($$PlaylistEntriesTableAnnotationComposer a) f) {
    final $$PlaylistEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistEntries,
        getReferencedColumn: (t) => t.songId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.playlistEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SongsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SongsTable,
    Song,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (Song, $$SongsTableReferences),
    Song,
    PrefetchHooks Function({bool lyricsLinesRefs, bool playlistEntriesRefs})> {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> number = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<String?> audioFilePath = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isFavorited = const Value.absent(),
            Value<bool> hasSyncedLyrics = const Value.absent(),
            Value<String?> lastPlayedAt = const Value.absent(),
          }) =>
              SongsCompanion(
            id: id,
            number: number,
            title: title,
            durationMs: durationMs,
            audioFilePath: audioFilePath,
            isDownloaded: isDownloaded,
            isFavorited: isFavorited,
            hasSyncedLyrics: hasSyncedLyrics,
            lastPlayedAt: lastPlayedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int number,
            required String title,
            Value<int?> durationMs = const Value.absent(),
            Value<String?> audioFilePath = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<bool> isFavorited = const Value.absent(),
            Value<bool> hasSyncedLyrics = const Value.absent(),
            Value<String?> lastPlayedAt = const Value.absent(),
          }) =>
              SongsCompanion.insert(
            id: id,
            number: number,
            title: title,
            durationMs: durationMs,
            audioFilePath: audioFilePath,
            isDownloaded: isDownloaded,
            isFavorited: isFavorited,
            hasSyncedLyrics: hasSyncedLyrics,
            lastPlayedAt: lastPlayedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SongsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {lyricsLinesRefs = false, playlistEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (lyricsLinesRefs) db.lyricsLines,
                if (playlistEntriesRefs) db.playlistEntries
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lyricsLinesRefs)
                    await $_getPrefetchedData<Song, $SongsTable, LyricsLine>(
                        currentTable: table,
                        referencedTable:
                            $$SongsTableReferences._lyricsLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SongsTableReferences(db, table, p0)
                                .lyricsLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.songId == item.id),
                        typedResults: items),
                  if (playlistEntriesRefs)
                    await $_getPrefetchedData<Song, $SongsTable, PlaylistEntry>(
                        currentTable: table,
                        referencedTable: $$SongsTableReferences
                            ._playlistEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SongsTableReferences(db, table, p0)
                                .playlistEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.songId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SongsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SongsTable,
    Song,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (Song, $$SongsTableReferences),
    Song,
    PrefetchHooks Function({bool lyricsLinesRefs, bool playlistEntriesRefs})>;
typedef $LyricsLinesCreateCompanionBuilder = LyricsLinesCompanion Function({
  Value<int> id,
  required int songId,
  required int lineIndex,
  Value<int> sectionIndex,
  required int startMs,
  required int endMs,
  required String lineText,
});
typedef $LyricsLinesUpdateCompanionBuilder = LyricsLinesCompanion Function({
  Value<int> id,
  Value<int> songId,
  Value<int> lineIndex,
  Value<int> sectionIndex,
  Value<int> startMs,
  Value<int> endMs,
  Value<String> lineText,
});

final class $LyricsLinesReferences
    extends BaseReferences<_$AppDatabase, LyricsLines, LyricsLine> {
  $LyricsLinesReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs
      .createAlias($_aliasNameGenerator(db.lyricsLines.songId, db.songs.id));

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<int>('song_id')!;

    final manager = $$SongsTableTableManager($_db, $_db.songs)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<LyricsWords, List<LyricsWord>>
      _lyricsWordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.lyricsWords,
          aliasName:
              $_aliasNameGenerator(db.lyricsLines.id, db.lyricsWords.lineId));

  $LyricsWordsProcessedTableManager get lyricsWordsRefs {
    final manager = $LyricsWordsTableManager($_db, $_db.lyricsWords)
        .filter((f) => f.lineId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lyricsWordsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $LyricsLinesFilterComposer extends Composer<_$AppDatabase, LyricsLines> {
  $LyricsLinesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lineIndex => $composableBuilder(
      column: $table.lineIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sectionIndex => $composableBuilder(
      column: $table.sectionIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startMs => $composableBuilder(
      column: $table.startMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endMs => $composableBuilder(
      column: $table.endMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lineText => $composableBuilder(
      column: $table.lineText, builder: (column) => ColumnFilters(column));

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.songId,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableFilterComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> lyricsWordsRefs(
      Expression<bool> Function($LyricsWordsFilterComposer f) f) {
    final $LyricsWordsFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lyricsWords,
        getReferencedColumn: (t) => t.lineId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $LyricsWordsFilterComposer(
              $db: $db,
              $table: $db.lyricsWords,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $LyricsLinesOrderingComposer
    extends Composer<_$AppDatabase, LyricsLines> {
  $LyricsLinesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lineIndex => $composableBuilder(
      column: $table.lineIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sectionIndex => $composableBuilder(
      column: $table.sectionIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startMs => $composableBuilder(
      column: $table.startMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endMs => $composableBuilder(
      column: $table.endMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lineText => $composableBuilder(
      column: $table.lineText, builder: (column) => ColumnOrderings(column));

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.songId,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableOrderingComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $LyricsLinesAnnotationComposer
    extends Composer<_$AppDatabase, LyricsLines> {
  $LyricsLinesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lineIndex =>
      $composableBuilder(column: $table.lineIndex, builder: (column) => column);

  GeneratedColumn<int> get sectionIndex => $composableBuilder(
      column: $table.sectionIndex, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get lineText =>
      $composableBuilder(column: $table.lineText, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.songId,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableAnnotationComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> lyricsWordsRefs<T extends Object>(
      Expression<T> Function($LyricsWordsAnnotationComposer a) f) {
    final $LyricsWordsAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lyricsWords,
        getReferencedColumn: (t) => t.lineId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $LyricsWordsAnnotationComposer(
              $db: $db,
              $table: $db.lyricsWords,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $LyricsLinesTableManager extends RootTableManager<
    _$AppDatabase,
    LyricsLines,
    LyricsLine,
    $LyricsLinesFilterComposer,
    $LyricsLinesOrderingComposer,
    $LyricsLinesAnnotationComposer,
    $LyricsLinesCreateCompanionBuilder,
    $LyricsLinesUpdateCompanionBuilder,
    (LyricsLine, $LyricsLinesReferences),
    LyricsLine,
    PrefetchHooks Function({bool songId, bool lyricsWordsRefs})> {
  $LyricsLinesTableManager(_$AppDatabase db, LyricsLines table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LyricsLinesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LyricsLinesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LyricsLinesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> songId = const Value.absent(),
            Value<int> lineIndex = const Value.absent(),
            Value<int> sectionIndex = const Value.absent(),
            Value<int> startMs = const Value.absent(),
            Value<int> endMs = const Value.absent(),
            Value<String> lineText = const Value.absent(),
          }) =>
              LyricsLinesCompanion(
            id: id,
            songId: songId,
            lineIndex: lineIndex,
            sectionIndex: sectionIndex,
            startMs: startMs,
            endMs: endMs,
            lineText: lineText,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int songId,
            required int lineIndex,
            Value<int> sectionIndex = const Value.absent(),
            required int startMs,
            required int endMs,
            required String lineText,
          }) =>
              LyricsLinesCompanion.insert(
            id: id,
            songId: songId,
            lineIndex: lineIndex,
            sectionIndex: sectionIndex,
            startMs: startMs,
            endMs: endMs,
            lineText: lineText,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $LyricsLinesReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({songId = false, lyricsWordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (lyricsWordsRefs) db.lyricsWords],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (songId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.songId,
                    referencedTable: $LyricsLinesReferences._songIdTable(db),
                    referencedColumn:
                        $LyricsLinesReferences._songIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lyricsWordsRefs)
                    await $_getPrefetchedData<LyricsLine, LyricsLines,
                            LyricsWord>(
                        currentTable: table,
                        referencedTable:
                            $LyricsLinesReferences._lyricsWordsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $LyricsLinesReferences(db, table, p0)
                                .lyricsWordsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.lineId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $LyricsLinesProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    LyricsLines,
    LyricsLine,
    $LyricsLinesFilterComposer,
    $LyricsLinesOrderingComposer,
    $LyricsLinesAnnotationComposer,
    $LyricsLinesCreateCompanionBuilder,
    $LyricsLinesUpdateCompanionBuilder,
    (LyricsLine, $LyricsLinesReferences),
    LyricsLine,
    PrefetchHooks Function({bool songId, bool lyricsWordsRefs})>;
typedef $LyricsWordsCreateCompanionBuilder = LyricsWordsCompanion Function({
  Value<int> id,
  required int lineId,
  required int wordIndex,
  required int startMs,
  required int endMs,
  required String wordText,
});
typedef $LyricsWordsUpdateCompanionBuilder = LyricsWordsCompanion Function({
  Value<int> id,
  Value<int> lineId,
  Value<int> wordIndex,
  Value<int> startMs,
  Value<int> endMs,
  Value<String> wordText,
});

final class $LyricsWordsReferences
    extends BaseReferences<_$AppDatabase, LyricsWords, LyricsWord> {
  $LyricsWordsReferences(super.$_db, super.$_table, super.$_typedResult);

  static LyricsLines _lineIdTable(_$AppDatabase db) =>
      db.lyricsLines.createAlias(
          $_aliasNameGenerator(db.lyricsWords.lineId, db.lyricsLines.id));

  $LyricsLinesProcessedTableManager get lineId {
    final $_column = $_itemColumn<int>('line_id')!;

    final manager = $LyricsLinesTableManager($_db, $_db.lyricsLines)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $LyricsWordsFilterComposer extends Composer<_$AppDatabase, LyricsWords> {
  $LyricsWordsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wordIndex => $composableBuilder(
      column: $table.wordIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startMs => $composableBuilder(
      column: $table.startMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endMs => $composableBuilder(
      column: $table.endMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wordText => $composableBuilder(
      column: $table.wordText, builder: (column) => ColumnFilters(column));

  $LyricsLinesFilterComposer get lineId {
    final $LyricsLinesFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.lyricsLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $LyricsLinesFilterComposer(
              $db: $db,
              $table: $db.lyricsLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $LyricsWordsOrderingComposer
    extends Composer<_$AppDatabase, LyricsWords> {
  $LyricsWordsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wordIndex => $composableBuilder(
      column: $table.wordIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startMs => $composableBuilder(
      column: $table.startMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endMs => $composableBuilder(
      column: $table.endMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wordText => $composableBuilder(
      column: $table.wordText, builder: (column) => ColumnOrderings(column));

  $LyricsLinesOrderingComposer get lineId {
    final $LyricsLinesOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.lyricsLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $LyricsLinesOrderingComposer(
              $db: $db,
              $table: $db.lyricsLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $LyricsWordsAnnotationComposer
    extends Composer<_$AppDatabase, LyricsWords> {
  $LyricsWordsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get wordIndex =>
      $composableBuilder(column: $table.wordIndex, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get wordText =>
      $composableBuilder(column: $table.wordText, builder: (column) => column);

  $LyricsLinesAnnotationComposer get lineId {
    final $LyricsLinesAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.lyricsLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $LyricsLinesAnnotationComposer(
              $db: $db,
              $table: $db.lyricsLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $LyricsWordsTableManager extends RootTableManager<
    _$AppDatabase,
    LyricsWords,
    LyricsWord,
    $LyricsWordsFilterComposer,
    $LyricsWordsOrderingComposer,
    $LyricsWordsAnnotationComposer,
    $LyricsWordsCreateCompanionBuilder,
    $LyricsWordsUpdateCompanionBuilder,
    (LyricsWord, $LyricsWordsReferences),
    LyricsWord,
    PrefetchHooks Function({bool lineId})> {
  $LyricsWordsTableManager(_$AppDatabase db, LyricsWords table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LyricsWordsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LyricsWordsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LyricsWordsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> lineId = const Value.absent(),
            Value<int> wordIndex = const Value.absent(),
            Value<int> startMs = const Value.absent(),
            Value<int> endMs = const Value.absent(),
            Value<String> wordText = const Value.absent(),
          }) =>
              LyricsWordsCompanion(
            id: id,
            lineId: lineId,
            wordIndex: wordIndex,
            startMs: startMs,
            endMs: endMs,
            wordText: wordText,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int lineId,
            required int wordIndex,
            required int startMs,
            required int endMs,
            required String wordText,
          }) =>
              LyricsWordsCompanion.insert(
            id: id,
            lineId: lineId,
            wordIndex: wordIndex,
            startMs: startMs,
            endMs: endMs,
            wordText: wordText,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $LyricsWordsReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({lineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (lineId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.lineId,
                    referencedTable: $LyricsWordsReferences._lineIdTable(db),
                    referencedColumn:
                        $LyricsWordsReferences._lineIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $LyricsWordsProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    LyricsWords,
    LyricsWord,
    $LyricsWordsFilterComposer,
    $LyricsWordsOrderingComposer,
    $LyricsWordsAnnotationComposer,
    $LyricsWordsCreateCompanionBuilder,
    $LyricsWordsUpdateCompanionBuilder,
    (LyricsWord, $LyricsWordsReferences),
    LyricsWord,
    PrefetchHooks Function({bool lineId})>;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistEntriesTable, List<PlaylistEntry>>
      _playlistEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playlistEntries,
              aliasName: $_aliasNameGenerator(
                  db.playlists.id, db.playlistEntries.playlistId));

  $$PlaylistEntriesTableProcessedTableManager get playlistEntriesRefs {
    final manager =
        $$PlaylistEntriesTableTableManager($_db, $_db.playlistEntries)
            .filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_playlistEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  Expression<bool> playlistEntriesRefs(
      Expression<bool> Function($$PlaylistEntriesTableFilterComposer f) f) {
    final $$PlaylistEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistEntries,
        getReferencedColumn: (t) => t.playlistId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistEntriesTableFilterComposer(
              $db: $db,
              $table: $db.playlistEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> playlistEntriesRefs<T extends Object>(
      Expression<T> Function($$PlaylistEntriesTableAnnotationComposer a) f) {
    final $$PlaylistEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistEntries,
        getReferencedColumn: (t) => t.playlistId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.playlistEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlaylistsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, $$PlaylistsTableReferences),
    Playlist,
    PrefetchHooks Function({bool playlistEntriesRefs})> {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) =>
              PlaylistsCompanion(
            id: id,
            name: name,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) =>
              PlaylistsCompanion.insert(
            id: id,
            name: name,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PlaylistsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistEntriesRefs) db.playlistEntries
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistEntriesRefs)
                    await $_getPrefetchedData<Playlist, $PlaylistsTable,
                            PlaylistEntry>(
                        currentTable: table,
                        referencedTable: $$PlaylistsTableReferences
                            ._playlistEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlaylistsTableReferences(db, table, p0)
                                .playlistEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.playlistId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlaylistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, $$PlaylistsTableReferences),
    Playlist,
    PrefetchHooks Function({bool playlistEntriesRefs})>;
typedef $$PlaylistEntriesTableCreateCompanionBuilder = PlaylistEntriesCompanion
    Function({
  required int playlistId,
  required int songId,
  required int position,
  Value<int> rowid,
});
typedef $$PlaylistEntriesTableUpdateCompanionBuilder = PlaylistEntriesCompanion
    Function({
  Value<int> playlistId,
  Value<int> songId,
  Value<int> position,
  Value<int> rowid,
});

final class $$PlaylistEntriesTableReferences extends BaseReferences<
    _$AppDatabase, $PlaylistEntriesTable, PlaylistEntry> {
  $$PlaylistEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias(
          $_aliasNameGenerator(db.playlistEntries.playlistId, db.playlists.id));

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager($_db, $_db.playlists)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
      $_aliasNameGenerator(db.playlistEntries.songId, db.songs.id));

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<int>('song_id')!;

    final manager = $$SongsTableTableManager($_db, $_db.songs)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlaylistEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableFilterComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.songId,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableFilterComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableOrderingComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.songId,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableOrderingComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableAnnotationComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.songId,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableAnnotationComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistEntriesTable,
    PlaylistEntry,
    $$PlaylistEntriesTableFilterComposer,
    $$PlaylistEntriesTableOrderingComposer,
    $$PlaylistEntriesTableAnnotationComposer,
    $$PlaylistEntriesTableCreateCompanionBuilder,
    $$PlaylistEntriesTableUpdateCompanionBuilder,
    (PlaylistEntry, $$PlaylistEntriesTableReferences),
    PlaylistEntry,
    PrefetchHooks Function({bool playlistId, bool songId})> {
  $$PlaylistEntriesTableTableManager(
      _$AppDatabase db, $PlaylistEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> playlistId = const Value.absent(),
            Value<int> songId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistEntriesCompanion(
            playlistId: playlistId,
            songId: songId,
            position: position,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int playlistId,
            required int songId,
            required int position,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistEntriesCompanion.insert(
            playlistId: playlistId,
            songId: songId,
            position: position,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PlaylistEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistId = false, songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (playlistId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.playlistId,
                    referencedTable:
                        $$PlaylistEntriesTableReferences._playlistIdTable(db),
                    referencedColumn: $$PlaylistEntriesTableReferences
                        ._playlistIdTable(db)
                        .id,
                  ) as T;
                }
                if (songId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.songId,
                    referencedTable:
                        $$PlaylistEntriesTableReferences._songIdTable(db),
                    referencedColumn:
                        $$PlaylistEntriesTableReferences._songIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PlaylistEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistEntriesTable,
    PlaylistEntry,
    $$PlaylistEntriesTableFilterComposer,
    $$PlaylistEntriesTableOrderingComposer,
    $$PlaylistEntriesTableAnnotationComposer,
    $$PlaylistEntriesTableCreateCompanionBuilder,
    $$PlaylistEntriesTableUpdateCompanionBuilder,
    (PlaylistEntry, $$PlaylistEntriesTableReferences),
    PlaylistEntry,
    PrefetchHooks Function({bool playlistId, bool songId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $LyricsLinesTableManager get lyricsLines =>
      $LyricsLinesTableManager(_db, _db.lyricsLines);
  $LyricsWordsTableManager get lyricsWords =>
      $LyricsWordsTableManager(_db, _db.lyricsWords);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistEntriesTableTableManager get playlistEntries =>
      $$PlaylistEntriesTableTableManager(_db, _db.playlistEntries);
}
