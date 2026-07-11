// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_database.dart';

// ignore_for_file: type=lint
class $LibrarySourcesTable extends LibrarySources
    with TableInfo<$LibrarySourcesTable, LibrarySource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibrarySourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootUriMeta = const VerificationMeta(
    'rootUri',
  );
  @override
  late final GeneratedColumn<String> rootUri = GeneratedColumn<String>(
    'root_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _permissionBookmarkMeta =
      const VerificationMeta('permissionBookmark');
  @override
  late final GeneratedColumn<Uint8List> permissionBookmark =
      GeneratedColumn<Uint8List>(
        'permission_bookmark',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanRevisionMeta = const VerificationMeta(
    'scanRevision',
  );
  @override
  late final GeneratedColumn<int> scanRevision = GeneratedColumn<int>(
    'scan_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastScanStartedAtMeta = const VerificationMeta(
    'lastScanStartedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScanStartedAt =
      GeneratedColumn<DateTime>(
        'last_scan_started_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastScanCompletedAtMeta =
      const VerificationMeta('lastScanCompletedAt');
  @override
  late final GeneratedColumn<DateTime> lastScanCompletedAt =
      GeneratedColumn<DateTime>(
        'last_scan_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    displayName,
    rootUri,
    permissionBookmark,
    status,
    scanRevision,
    lastScanStartedAt,
    lastScanCompletedAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibrarySource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('root_uri')) {
      context.handle(
        _rootUriMeta,
        rootUri.isAcceptableOrUnknown(data['root_uri']!, _rootUriMeta),
      );
    } else if (isInserting) {
      context.missing(_rootUriMeta);
    }
    if (data.containsKey('permission_bookmark')) {
      context.handle(
        _permissionBookmarkMeta,
        permissionBookmark.isAcceptableOrUnknown(
          data['permission_bookmark']!,
          _permissionBookmarkMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('scan_revision')) {
      context.handle(
        _scanRevisionMeta,
        scanRevision.isAcceptableOrUnknown(
          data['scan_revision']!,
          _scanRevisionMeta,
        ),
      );
    }
    if (data.containsKey('last_scan_started_at')) {
      context.handle(
        _lastScanStartedAtMeta,
        lastScanStartedAt.isAcceptableOrUnknown(
          data['last_scan_started_at']!,
          _lastScanStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_scan_completed_at')) {
      context.handle(
        _lastScanCompletedAtMeta,
        lastScanCompletedAt.isAcceptableOrUnknown(
          data['last_scan_completed_at']!,
          _lastScanCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {type, rootUri},
  ];
  @override
  LibrarySource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibrarySource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      rootUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_uri'],
      )!,
      permissionBookmark: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}permission_bookmark'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      scanRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scan_revision'],
      )!,
      lastScanStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scan_started_at'],
      ),
      lastScanCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scan_completed_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LibrarySourcesTable createAlias(String alias) {
    return $LibrarySourcesTable(attachedDatabase, alias);
  }
}

class LibrarySource extends DataClass implements Insertable<LibrarySource> {
  final String id;
  final String type;
  final String displayName;
  final String rootUri;
  final Uint8List? permissionBookmark;
  final String status;
  final int scanRevision;
  final DateTime? lastScanStartedAt;
  final DateTime? lastScanCompletedAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LibrarySource({
    required this.id,
    required this.type,
    required this.displayName,
    required this.rootUri,
    this.permissionBookmark,
    required this.status,
    required this.scanRevision,
    this.lastScanStartedAt,
    this.lastScanCompletedAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['display_name'] = Variable<String>(displayName);
    map['root_uri'] = Variable<String>(rootUri);
    if (!nullToAbsent || permissionBookmark != null) {
      map['permission_bookmark'] = Variable<Uint8List>(permissionBookmark);
    }
    map['status'] = Variable<String>(status);
    map['scan_revision'] = Variable<int>(scanRevision);
    if (!nullToAbsent || lastScanStartedAt != null) {
      map['last_scan_started_at'] = Variable<DateTime>(lastScanStartedAt);
    }
    if (!nullToAbsent || lastScanCompletedAt != null) {
      map['last_scan_completed_at'] = Variable<DateTime>(lastScanCompletedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LibrarySourcesCompanion toCompanion(bool nullToAbsent) {
    return LibrarySourcesCompanion(
      id: Value(id),
      type: Value(type),
      displayName: Value(displayName),
      rootUri: Value(rootUri),
      permissionBookmark: permissionBookmark == null && nullToAbsent
          ? const Value.absent()
          : Value(permissionBookmark),
      status: Value(status),
      scanRevision: Value(scanRevision),
      lastScanStartedAt: lastScanStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanStartedAt),
      lastScanCompletedAt: lastScanCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanCompletedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LibrarySource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibrarySource(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      displayName: serializer.fromJson<String>(json['displayName']),
      rootUri: serializer.fromJson<String>(json['rootUri']),
      permissionBookmark: serializer.fromJson<Uint8List?>(
        json['permissionBookmark'],
      ),
      status: serializer.fromJson<String>(json['status']),
      scanRevision: serializer.fromJson<int>(json['scanRevision']),
      lastScanStartedAt: serializer.fromJson<DateTime?>(
        json['lastScanStartedAt'],
      ),
      lastScanCompletedAt: serializer.fromJson<DateTime?>(
        json['lastScanCompletedAt'],
      ),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'displayName': serializer.toJson<String>(displayName),
      'rootUri': serializer.toJson<String>(rootUri),
      'permissionBookmark': serializer.toJson<Uint8List?>(permissionBookmark),
      'status': serializer.toJson<String>(status),
      'scanRevision': serializer.toJson<int>(scanRevision),
      'lastScanStartedAt': serializer.toJson<DateTime?>(lastScanStartedAt),
      'lastScanCompletedAt': serializer.toJson<DateTime?>(lastScanCompletedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LibrarySource copyWith({
    String? id,
    String? type,
    String? displayName,
    String? rootUri,
    Value<Uint8List?> permissionBookmark = const Value.absent(),
    String? status,
    int? scanRevision,
    Value<DateTime?> lastScanStartedAt = const Value.absent(),
    Value<DateTime?> lastScanCompletedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LibrarySource(
    id: id ?? this.id,
    type: type ?? this.type,
    displayName: displayName ?? this.displayName,
    rootUri: rootUri ?? this.rootUri,
    permissionBookmark: permissionBookmark.present
        ? permissionBookmark.value
        : this.permissionBookmark,
    status: status ?? this.status,
    scanRevision: scanRevision ?? this.scanRevision,
    lastScanStartedAt: lastScanStartedAt.present
        ? lastScanStartedAt.value
        : this.lastScanStartedAt,
    lastScanCompletedAt: lastScanCompletedAt.present
        ? lastScanCompletedAt.value
        : this.lastScanCompletedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LibrarySource copyWithCompanion(LibrarySourcesCompanion data) {
    return LibrarySource(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      rootUri: data.rootUri.present ? data.rootUri.value : this.rootUri,
      permissionBookmark: data.permissionBookmark.present
          ? data.permissionBookmark.value
          : this.permissionBookmark,
      status: data.status.present ? data.status.value : this.status,
      scanRevision: data.scanRevision.present
          ? data.scanRevision.value
          : this.scanRevision,
      lastScanStartedAt: data.lastScanStartedAt.present
          ? data.lastScanStartedAt.value
          : this.lastScanStartedAt,
      lastScanCompletedAt: data.lastScanCompletedAt.present
          ? data.lastScanCompletedAt.value
          : this.lastScanCompletedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySource(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('displayName: $displayName, ')
          ..write('rootUri: $rootUri, ')
          ..write('permissionBookmark: $permissionBookmark, ')
          ..write('status: $status, ')
          ..write('scanRevision: $scanRevision, ')
          ..write('lastScanStartedAt: $lastScanStartedAt, ')
          ..write('lastScanCompletedAt: $lastScanCompletedAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    displayName,
    rootUri,
    $driftBlobEquality.hash(permissionBookmark),
    status,
    scanRevision,
    lastScanStartedAt,
    lastScanCompletedAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibrarySource &&
          other.id == this.id &&
          other.type == this.type &&
          other.displayName == this.displayName &&
          other.rootUri == this.rootUri &&
          $driftBlobEquality.equals(
            other.permissionBookmark,
            this.permissionBookmark,
          ) &&
          other.status == this.status &&
          other.scanRevision == this.scanRevision &&
          other.lastScanStartedAt == this.lastScanStartedAt &&
          other.lastScanCompletedAt == this.lastScanCompletedAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LibrarySourcesCompanion extends UpdateCompanion<LibrarySource> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> displayName;
  final Value<String> rootUri;
  final Value<Uint8List?> permissionBookmark;
  final Value<String> status;
  final Value<int> scanRevision;
  final Value<DateTime?> lastScanStartedAt;
  final Value<DateTime?> lastScanCompletedAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LibrarySourcesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.permissionBookmark = const Value.absent(),
    this.status = const Value.absent(),
    this.scanRevision = const Value.absent(),
    this.lastScanStartedAt = const Value.absent(),
    this.lastScanCompletedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibrarySourcesCompanion.insert({
    required String id,
    required String type,
    required String displayName,
    required String rootUri,
    this.permissionBookmark = const Value.absent(),
    required String status,
    this.scanRevision = const Value.absent(),
    this.lastScanStartedAt = const Value.absent(),
    this.lastScanCompletedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       displayName = Value(displayName),
       rootUri = Value(rootUri),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LibrarySource> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? displayName,
    Expression<String>? rootUri,
    Expression<Uint8List>? permissionBookmark,
    Expression<String>? status,
    Expression<int>? scanRevision,
    Expression<DateTime>? lastScanStartedAt,
    Expression<DateTime>? lastScanCompletedAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (displayName != null) 'display_name': displayName,
      if (rootUri != null) 'root_uri': rootUri,
      if (permissionBookmark != null) 'permission_bookmark': permissionBookmark,
      if (status != null) 'status': status,
      if (scanRevision != null) 'scan_revision': scanRevision,
      if (lastScanStartedAt != null) 'last_scan_started_at': lastScanStartedAt,
      if (lastScanCompletedAt != null)
        'last_scan_completed_at': lastScanCompletedAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibrarySourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? displayName,
    Value<String>? rootUri,
    Value<Uint8List?>? permissionBookmark,
    Value<String>? status,
    Value<int>? scanRevision,
    Value<DateTime?>? lastScanStartedAt,
    Value<DateTime?>? lastScanCompletedAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LibrarySourcesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      rootUri: rootUri ?? this.rootUri,
      permissionBookmark: permissionBookmark ?? this.permissionBookmark,
      status: status ?? this.status,
      scanRevision: scanRevision ?? this.scanRevision,
      lastScanStartedAt: lastScanStartedAt ?? this.lastScanStartedAt,
      lastScanCompletedAt: lastScanCompletedAt ?? this.lastScanCompletedAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rootUri.present) {
      map['root_uri'] = Variable<String>(rootUri.value);
    }
    if (permissionBookmark.present) {
      map['permission_bookmark'] = Variable<Uint8List>(
        permissionBookmark.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scanRevision.present) {
      map['scan_revision'] = Variable<int>(scanRevision.value);
    }
    if (lastScanStartedAt.present) {
      map['last_scan_started_at'] = Variable<DateTime>(lastScanStartedAt.value);
    }
    if (lastScanCompletedAt.present) {
      map['last_scan_completed_at'] = Variable<DateTime>(
        lastScanCompletedAt.value,
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySourcesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('displayName: $displayName, ')
          ..write('rootUri: $rootUri, ')
          ..write('permissionBookmark: $permissionBookmark, ')
          ..write('status: $status, ')
          ..write('scanRevision: $scanRevision, ')
          ..write('lastScanStartedAt: $lastScanStartedAt, ')
          ..write('lastScanCompletedAt: $lastScanCompletedAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryArtistsTable extends LibraryArtists
    with TableInfo<$LibraryArtistsTable, LibraryArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortNameMeta = const VerificationMeta(
    'sortName',
  );
  @override
  late final GeneratedColumn<String> sortName = GeneratedColumn<String>(
    'sort_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sourceId, name, sortName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_name')) {
      context.handle(
        _sortNameMeta,
        sortName.isAcceptableOrUnknown(data['sort_name']!, _sortNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sortNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, sortName},
  ];
  @override
  LibraryArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryArtist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_name'],
      )!,
    );
  }

  @override
  $LibraryArtistsTable createAlias(String alias) {
    return $LibraryArtistsTable(attachedDatabase, alias);
  }
}

class LibraryArtist extends DataClass implements Insertable<LibraryArtist> {
  final String id;
  final String sourceId;
  final String name;
  final String sortName;
  const LibraryArtist({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.sortName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['name'] = Variable<String>(name);
    map['sort_name'] = Variable<String>(sortName);
    return map;
  }

  LibraryArtistsCompanion toCompanion(bool nullToAbsent) {
    return LibraryArtistsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      name: Value(name),
      sortName: Value(sortName),
    );
  }

  factory LibraryArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryArtist(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      name: serializer.fromJson<String>(json['name']),
      sortName: serializer.fromJson<String>(json['sortName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'name': serializer.toJson<String>(name),
      'sortName': serializer.toJson<String>(sortName),
    };
  }

  LibraryArtist copyWith({
    String? id,
    String? sourceId,
    String? name,
    String? sortName,
  }) => LibraryArtist(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    name: name ?? this.name,
    sortName: sortName ?? this.sortName,
  );
  LibraryArtist copyWithCompanion(LibraryArtistsCompanion data) {
    return LibraryArtist(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      name: data.name.present ? data.name.value : this.name,
      sortName: data.sortName.present ? data.sortName.value : this.sortName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryArtist(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('sortName: $sortName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, name, sortName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryArtist &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.name == this.name &&
          other.sortName == this.sortName);
}

class LibraryArtistsCompanion extends UpdateCompanion<LibraryArtist> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> name;
  final Value<String> sortName;
  final Value<int> rowid;
  const LibraryArtistsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryArtistsCompanion.insert({
    required String id,
    required String sourceId,
    required String name,
    required String sortName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       name = Value(name),
       sortName = Value(sortName);
  static Insertable<LibraryArtist> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? name,
    Expression<String>? sortName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (name != null) 'name': name,
      if (sortName != null) 'sort_name': sortName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryArtistsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? name,
    Value<String>? sortName,
    Value<int>? rowid,
  }) {
    return LibraryArtistsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      sortName: sortName ?? this.sortName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortName.present) {
      map['sort_name'] = Variable<String>(sortName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryArtistsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('sortName: $sortName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryAlbumsTable extends LibraryAlbums
    with TableInfo<$LibraryAlbumsTable, LibraryAlbum> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryAlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_artists (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortTitleMeta = const VerificationMeta(
    'sortTitle',
  );
  @override
  late final GeneratedColumn<String> sortTitle = GeneratedColumn<String>(
    'sort_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkKeyMeta = const VerificationMeta(
    'artworkKey',
  );
  @override
  late final GeneratedColumn<String> artworkKey = GeneratedColumn<String>(
    'artwork_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    artistId,
    title,
    sortTitle,
    albumArtist,
    year,
    genre,
    artworkKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryAlbum> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('sort_title')) {
      context.handle(
        _sortTitleMeta,
        sortTitle.isAcceptableOrUnknown(data['sort_title']!, _sortTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_sortTitleMeta);
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_albumArtistMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('artwork_key')) {
      context.handle(
        _artworkKeyMeta,
        artworkKey.isAcceptableOrUnknown(data['artwork_key']!, _artworkKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, albumArtist, sortTitle},
  ];
  @override
  LibraryAlbum map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryAlbum(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sortTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_title'],
      )!,
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      artworkKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_key'],
      ),
    );
  }

  @override
  $LibraryAlbumsTable createAlias(String alias) {
    return $LibraryAlbumsTable(attachedDatabase, alias);
  }
}

class LibraryAlbum extends DataClass implements Insertable<LibraryAlbum> {
  final String id;
  final String sourceId;
  final String? artistId;
  final String title;
  final String sortTitle;
  final String albumArtist;
  final int? year;
  final String? genre;
  final String? artworkKey;
  const LibraryAlbum({
    required this.id,
    required this.sourceId,
    this.artistId,
    required this.title,
    required this.sortTitle,
    required this.albumArtist,
    this.year,
    this.genre,
    this.artworkKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<String>(artistId);
    }
    map['title'] = Variable<String>(title);
    map['sort_title'] = Variable<String>(sortTitle);
    map['album_artist'] = Variable<String>(albumArtist);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || artworkKey != null) {
      map['artwork_key'] = Variable<String>(artworkKey);
    }
    return map;
  }

  LibraryAlbumsCompanion toCompanion(bool nullToAbsent) {
    return LibraryAlbumsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      title: Value(title),
      sortTitle: Value(sortTitle),
      albumArtist: Value(albumArtist),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      artworkKey: artworkKey == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkKey),
    );
  }

  factory LibraryAlbum.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryAlbum(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      title: serializer.fromJson<String>(json['title']),
      sortTitle: serializer.fromJson<String>(json['sortTitle']),
      albumArtist: serializer.fromJson<String>(json['albumArtist']),
      year: serializer.fromJson<int?>(json['year']),
      genre: serializer.fromJson<String?>(json['genre']),
      artworkKey: serializer.fromJson<String?>(json['artworkKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'artistId': serializer.toJson<String?>(artistId),
      'title': serializer.toJson<String>(title),
      'sortTitle': serializer.toJson<String>(sortTitle),
      'albumArtist': serializer.toJson<String>(albumArtist),
      'year': serializer.toJson<int?>(year),
      'genre': serializer.toJson<String?>(genre),
      'artworkKey': serializer.toJson<String?>(artworkKey),
    };
  }

  LibraryAlbum copyWith({
    String? id,
    String? sourceId,
    Value<String?> artistId = const Value.absent(),
    String? title,
    String? sortTitle,
    String? albumArtist,
    Value<int?> year = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> artworkKey = const Value.absent(),
  }) => LibraryAlbum(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    artistId: artistId.present ? artistId.value : this.artistId,
    title: title ?? this.title,
    sortTitle: sortTitle ?? this.sortTitle,
    albumArtist: albumArtist ?? this.albumArtist,
    year: year.present ? year.value : this.year,
    genre: genre.present ? genre.value : this.genre,
    artworkKey: artworkKey.present ? artworkKey.value : this.artworkKey,
  );
  LibraryAlbum copyWithCompanion(LibraryAlbumsCompanion data) {
    return LibraryAlbum(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      title: data.title.present ? data.title.value : this.title,
      sortTitle: data.sortTitle.present ? data.sortTitle.value : this.sortTitle,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      year: data.year.present ? data.year.value : this.year,
      genre: data.genre.present ? data.genre.value : this.genre,
      artworkKey: data.artworkKey.present
          ? data.artworkKey.value
          : this.artworkKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryAlbum(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('artistId: $artistId, ')
          ..write('title: $title, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('artworkKey: $artworkKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    artistId,
    title,
    sortTitle,
    albumArtist,
    year,
    genre,
    artworkKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryAlbum &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.artistId == this.artistId &&
          other.title == this.title &&
          other.sortTitle == this.sortTitle &&
          other.albumArtist == this.albumArtist &&
          other.year == this.year &&
          other.genre == this.genre &&
          other.artworkKey == this.artworkKey);
}

class LibraryAlbumsCompanion extends UpdateCompanion<LibraryAlbum> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String?> artistId;
  final Value<String> title;
  final Value<String> sortTitle;
  final Value<String> albumArtist;
  final Value<int?> year;
  final Value<String?> genre;
  final Value<String?> artworkKey;
  final Value<int> rowid;
  const LibraryAlbumsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.title = const Value.absent(),
    this.sortTitle = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.artworkKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryAlbumsCompanion.insert({
    required String id,
    required String sourceId,
    this.artistId = const Value.absent(),
    required String title,
    required String sortTitle,
    required String albumArtist,
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.artworkKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       title = Value(title),
       sortTitle = Value(sortTitle),
       albumArtist = Value(albumArtist);
  static Insertable<LibraryAlbum> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? artistId,
    Expression<String>? title,
    Expression<String>? sortTitle,
    Expression<String>? albumArtist,
    Expression<int>? year,
    Expression<String>? genre,
    Expression<String>? artworkKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (artistId != null) 'artist_id': artistId,
      if (title != null) 'title': title,
      if (sortTitle != null) 'sort_title': sortTitle,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (artworkKey != null) 'artwork_key': artworkKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryAlbumsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String?>? artistId,
    Value<String>? title,
    Value<String>? sortTitle,
    Value<String>? albumArtist,
    Value<int?>? year,
    Value<String?>? genre,
    Value<String?>? artworkKey,
    Value<int>? rowid,
  }) {
    return LibraryAlbumsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      artistId: artistId ?? this.artistId,
      title: title ?? this.title,
      sortTitle: sortTitle ?? this.sortTitle,
      albumArtist: albumArtist ?? this.albumArtist,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      artworkKey: artworkKey ?? this.artworkKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sortTitle.present) {
      map['sort_title'] = Variable<String>(sortTitle.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (artworkKey.present) {
      map['artwork_key'] = Variable<String>(artworkKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryAlbumsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('artistId: $artistId, ')
          ..write('title: $title, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('artworkKey: $artworkKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryTracksTable extends LibraryTracks
    with TableInfo<$LibraryTracksTable, LibraryTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_albums (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_artists (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaUriMeta = const VerificationMeta(
    'mediaUri',
  );
  @override
  late final GeneratedColumn<String> mediaUri = GeneratedColumn<String>(
    'media_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumTitleMeta = const VerificationMeta(
    'albumTitle',
  );
  @override
  late final GeneratedColumn<String> albumTitle = GeneratedColumn<String>(
    'album_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artworkKeyMeta = const VerificationMeta(
    'artworkKey',
  );
  @override
  late final GeneratedColumn<String> artworkKey = GeneratedColumn<String>(
    'artwork_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    albumId,
    artistId,
    relativePath,
    mediaUri,
    title,
    artistName,
    albumTitle,
    durationMs,
    trackNumber,
    discNumber,
    year,
    genre,
    contentType,
    fileSize,
    modifiedAt,
    artworkKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('media_uri')) {
      context.handle(
        _mediaUriMeta,
        mediaUri.isAcceptableOrUnknown(data['media_uri']!, _mediaUriMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaUriMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    if (data.containsKey('album_title')) {
      context.handle(
        _albumTitleMeta,
        albumTitle.isAcceptableOrUnknown(data['album_title']!, _albumTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_albumTitleMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    if (data.containsKey('artwork_key')) {
      context.handle(
        _artworkKeyMeta,
        artworkKey.isAcceptableOrUnknown(data['artwork_key']!, _artworkKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, relativePath},
  ];
  @override
  LibraryTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      ),
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      ),
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      mediaUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_uri'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artistName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_name'],
      )!,
      albumTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_title'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      )!,
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
      artworkKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_key'],
      ),
    );
  }

  @override
  $LibraryTracksTable createAlias(String alias) {
    return $LibraryTracksTable(attachedDatabase, alias);
  }
}

class LibraryTrack extends DataClass implements Insertable<LibraryTrack> {
  final String id;
  final String sourceId;
  final String? albumId;
  final String? artistId;
  final String relativePath;
  final String mediaUri;
  final String title;
  final String artistName;
  final String albumTitle;
  final int durationMs;
  final int trackNumber;
  final int discNumber;
  final int? year;
  final String? genre;
  final String? contentType;
  final int? fileSize;
  final DateTime modifiedAt;
  final String? artworkKey;
  const LibraryTrack({
    required this.id,
    required this.sourceId,
    this.albumId,
    this.artistId,
    required this.relativePath,
    required this.mediaUri,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.durationMs,
    required this.trackNumber,
    required this.discNumber,
    this.year,
    this.genre,
    this.contentType,
    this.fileSize,
    required this.modifiedAt,
    this.artworkKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || albumId != null) {
      map['album_id'] = Variable<String>(albumId);
    }
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<String>(artistId);
    }
    map['relative_path'] = Variable<String>(relativePath);
    map['media_uri'] = Variable<String>(mediaUri);
    map['title'] = Variable<String>(title);
    map['artist_name'] = Variable<String>(artistName);
    map['album_title'] = Variable<String>(albumTitle);
    map['duration_ms'] = Variable<int>(durationMs);
    map['track_number'] = Variable<int>(trackNumber);
    map['disc_number'] = Variable<int>(discNumber);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    if (!nullToAbsent || artworkKey != null) {
      map['artwork_key'] = Variable<String>(artworkKey);
    }
    return map;
  }

  LibraryTracksCompanion toCompanion(bool nullToAbsent) {
    return LibraryTracksCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      albumId: albumId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumId),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      relativePath: Value(relativePath),
      mediaUri: Value(mediaUri),
      title: Value(title),
      artistName: Value(artistName),
      albumTitle: Value(albumTitle),
      durationMs: Value(durationMs),
      trackNumber: Value(trackNumber),
      discNumber: Value(discNumber),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      modifiedAt: Value(modifiedAt),
      artworkKey: artworkKey == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkKey),
    );
  }

  factory LibraryTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryTrack(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      albumId: serializer.fromJson<String?>(json['albumId']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      mediaUri: serializer.fromJson<String>(json['mediaUri']),
      title: serializer.fromJson<String>(json['title']),
      artistName: serializer.fromJson<String>(json['artistName']),
      albumTitle: serializer.fromJson<String>(json['albumTitle']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      trackNumber: serializer.fromJson<int>(json['trackNumber']),
      discNumber: serializer.fromJson<int>(json['discNumber']),
      year: serializer.fromJson<int?>(json['year']),
      genre: serializer.fromJson<String?>(json['genre']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
      artworkKey: serializer.fromJson<String?>(json['artworkKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'albumId': serializer.toJson<String?>(albumId),
      'artistId': serializer.toJson<String?>(artistId),
      'relativePath': serializer.toJson<String>(relativePath),
      'mediaUri': serializer.toJson<String>(mediaUri),
      'title': serializer.toJson<String>(title),
      'artistName': serializer.toJson<String>(artistName),
      'albumTitle': serializer.toJson<String>(albumTitle),
      'durationMs': serializer.toJson<int>(durationMs),
      'trackNumber': serializer.toJson<int>(trackNumber),
      'discNumber': serializer.toJson<int>(discNumber),
      'year': serializer.toJson<int?>(year),
      'genre': serializer.toJson<String?>(genre),
      'contentType': serializer.toJson<String?>(contentType),
      'fileSize': serializer.toJson<int?>(fileSize),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
      'artworkKey': serializer.toJson<String?>(artworkKey),
    };
  }

  LibraryTrack copyWith({
    String? id,
    String? sourceId,
    Value<String?> albumId = const Value.absent(),
    Value<String?> artistId = const Value.absent(),
    String? relativePath,
    String? mediaUri,
    String? title,
    String? artistName,
    String? albumTitle,
    int? durationMs,
    int? trackNumber,
    int? discNumber,
    Value<int?> year = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> contentType = const Value.absent(),
    Value<int?> fileSize = const Value.absent(),
    DateTime? modifiedAt,
    Value<String?> artworkKey = const Value.absent(),
  }) => LibraryTrack(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    albumId: albumId.present ? albumId.value : this.albumId,
    artistId: artistId.present ? artistId.value : this.artistId,
    relativePath: relativePath ?? this.relativePath,
    mediaUri: mediaUri ?? this.mediaUri,
    title: title ?? this.title,
    artistName: artistName ?? this.artistName,
    albumTitle: albumTitle ?? this.albumTitle,
    durationMs: durationMs ?? this.durationMs,
    trackNumber: trackNumber ?? this.trackNumber,
    discNumber: discNumber ?? this.discNumber,
    year: year.present ? year.value : this.year,
    genre: genre.present ? genre.value : this.genre,
    contentType: contentType.present ? contentType.value : this.contentType,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    artworkKey: artworkKey.present ? artworkKey.value : this.artworkKey,
  );
  LibraryTrack copyWithCompanion(LibraryTracksCompanion data) {
    return LibraryTrack(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mediaUri: data.mediaUri.present ? data.mediaUri.value : this.mediaUri,
      title: data.title.present ? data.title.value : this.title,
      artistName: data.artistName.present
          ? data.artistName.value
          : this.artistName,
      albumTitle: data.albumTitle.present
          ? data.albumTitle.value
          : this.albumTitle,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      year: data.year.present ? data.year.value : this.year,
      genre: data.genre.present ? data.genre.value : this.genre,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      artworkKey: data.artworkKey.present
          ? data.artworkKey.value
          : this.artworkKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTrack(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaUri: $mediaUri, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('albumTitle: $albumTitle, ')
          ..write('durationMs: $durationMs, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('contentType: $contentType, ')
          ..write('fileSize: $fileSize, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('artworkKey: $artworkKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    albumId,
    artistId,
    relativePath,
    mediaUri,
    title,
    artistName,
    albumTitle,
    durationMs,
    trackNumber,
    discNumber,
    year,
    genre,
    contentType,
    fileSize,
    modifiedAt,
    artworkKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryTrack &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.albumId == this.albumId &&
          other.artistId == this.artistId &&
          other.relativePath == this.relativePath &&
          other.mediaUri == this.mediaUri &&
          other.title == this.title &&
          other.artistName == this.artistName &&
          other.albumTitle == this.albumTitle &&
          other.durationMs == this.durationMs &&
          other.trackNumber == this.trackNumber &&
          other.discNumber == this.discNumber &&
          other.year == this.year &&
          other.genre == this.genre &&
          other.contentType == this.contentType &&
          other.fileSize == this.fileSize &&
          other.modifiedAt == this.modifiedAt &&
          other.artworkKey == this.artworkKey);
}

class LibraryTracksCompanion extends UpdateCompanion<LibraryTrack> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String?> albumId;
  final Value<String?> artistId;
  final Value<String> relativePath;
  final Value<String> mediaUri;
  final Value<String> title;
  final Value<String> artistName;
  final Value<String> albumTitle;
  final Value<int> durationMs;
  final Value<int> trackNumber;
  final Value<int> discNumber;
  final Value<int?> year;
  final Value<String?> genre;
  final Value<String?> contentType;
  final Value<int?> fileSize;
  final Value<DateTime> modifiedAt;
  final Value<String?> artworkKey;
  final Value<int> rowid;
  const LibraryTracksCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mediaUri = const Value.absent(),
    this.title = const Value.absent(),
    this.artistName = const Value.absent(),
    this.albumTitle = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.contentType = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.artworkKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryTracksCompanion.insert({
    required String id,
    required String sourceId,
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    required String relativePath,
    required String mediaUri,
    required String title,
    required String artistName,
    required String albumTitle,
    required int durationMs,
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.contentType = const Value.absent(),
    this.fileSize = const Value.absent(),
    required DateTime modifiedAt,
    this.artworkKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       relativePath = Value(relativePath),
       mediaUri = Value(mediaUri),
       title = Value(title),
       artistName = Value(artistName),
       albumTitle = Value(albumTitle),
       durationMs = Value(durationMs),
       modifiedAt = Value(modifiedAt);
  static Insertable<LibraryTrack> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? albumId,
    Expression<String>? artistId,
    Expression<String>? relativePath,
    Expression<String>? mediaUri,
    Expression<String>? title,
    Expression<String>? artistName,
    Expression<String>? albumTitle,
    Expression<int>? durationMs,
    Expression<int>? trackNumber,
    Expression<int>? discNumber,
    Expression<int>? year,
    Expression<String>? genre,
    Expression<String>? contentType,
    Expression<int>? fileSize,
    Expression<DateTime>? modifiedAt,
    Expression<String>? artworkKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (albumId != null) 'album_id': albumId,
      if (artistId != null) 'artist_id': artistId,
      if (relativePath != null) 'relative_path': relativePath,
      if (mediaUri != null) 'media_uri': mediaUri,
      if (title != null) 'title': title,
      if (artistName != null) 'artist_name': artistName,
      if (albumTitle != null) 'album_title': albumTitle,
      if (durationMs != null) 'duration_ms': durationMs,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (contentType != null) 'content_type': contentType,
      if (fileSize != null) 'file_size': fileSize,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (artworkKey != null) 'artwork_key': artworkKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryTracksCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String?>? albumId,
    Value<String?>? artistId,
    Value<String>? relativePath,
    Value<String>? mediaUri,
    Value<String>? title,
    Value<String>? artistName,
    Value<String>? albumTitle,
    Value<int>? durationMs,
    Value<int>? trackNumber,
    Value<int>? discNumber,
    Value<int?>? year,
    Value<String?>? genre,
    Value<String?>? contentType,
    Value<int?>? fileSize,
    Value<DateTime>? modifiedAt,
    Value<String?>? artworkKey,
    Value<int>? rowid,
  }) {
    return LibraryTracksCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      relativePath: relativePath ?? this.relativePath,
      mediaUri: mediaUri ?? this.mediaUri,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumTitle: albumTitle ?? this.albumTitle,
      durationMs: durationMs ?? this.durationMs,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      contentType: contentType ?? this.contentType,
      fileSize: fileSize ?? this.fileSize,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      artworkKey: artworkKey ?? this.artworkKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mediaUri.present) {
      map['media_uri'] = Variable<String>(mediaUri.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (albumTitle.present) {
      map['album_title'] = Variable<String>(albumTitle.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (artworkKey.present) {
      map['artwork_key'] = Variable<String>(artworkKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTracksCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaUri: $mediaUri, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('albumTitle: $albumTitle, ')
          ..write('durationMs: $durationMs, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('contentType: $contentType, ')
          ..write('fileSize: $fileSize, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('artworkKey: $artworkKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryLyricsTable extends LibraryLyrics
    with TableInfo<$LibraryLyricsTable, LibraryLyric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryLyricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    sequence,
    timestampMs,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_lyrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryLyric> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId, sequence};
  @override
  LibraryLyric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryLyric(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
    );
  }

  @override
  $LibraryLyricsTable createAlias(String alias) {
    return $LibraryLyricsTable(attachedDatabase, alias);
  }
}

class LibraryLyric extends DataClass implements Insertable<LibraryLyric> {
  final String trackId;
  final int sequence;
  final int timestampMs;
  final String content;
  const LibraryLyric({
    required this.trackId,
    required this.sequence,
    required this.timestampMs,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['sequence'] = Variable<int>(sequence);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['text'] = Variable<String>(content);
    return map;
  }

  LibraryLyricsCompanion toCompanion(bool nullToAbsent) {
    return LibraryLyricsCompanion(
      trackId: Value(trackId),
      sequence: Value(sequence),
      timestampMs: Value(timestampMs),
      content: Value(content),
    );
  }

  factory LibraryLyric.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryLyric(
      trackId: serializer.fromJson<String>(json['trackId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'sequence': serializer.toJson<int>(sequence),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'content': serializer.toJson<String>(content),
    };
  }

  LibraryLyric copyWith({
    String? trackId,
    int? sequence,
    int? timestampMs,
    String? content,
  }) => LibraryLyric(
    trackId: trackId ?? this.trackId,
    sequence: sequence ?? this.sequence,
    timestampMs: timestampMs ?? this.timestampMs,
    content: content ?? this.content,
  );
  LibraryLyric copyWithCompanion(LibraryLyricsCompanion data) {
    return LibraryLyric(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryLyric(')
          ..write('trackId: $trackId, ')
          ..write('sequence: $sequence, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, sequence, timestampMs, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryLyric &&
          other.trackId == this.trackId &&
          other.sequence == this.sequence &&
          other.timestampMs == this.timestampMs &&
          other.content == this.content);
}

class LibraryLyricsCompanion extends UpdateCompanion<LibraryLyric> {
  final Value<String> trackId;
  final Value<int> sequence;
  final Value<int> timestampMs;
  final Value<String> content;
  final Value<int> rowid;
  const LibraryLyricsCompanion({
    this.trackId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryLyricsCompanion.insert({
    required String trackId,
    required int sequence,
    required int timestampMs,
    required String content,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       sequence = Value(sequence),
       timestampMs = Value(timestampMs),
       content = Value(content);
  static Insertable<LibraryLyric> custom({
    Expression<String>? trackId,
    Expression<int>? sequence,
    Expression<int>? timestampMs,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (sequence != null) 'sequence': sequence,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (content != null) 'text': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryLyricsCompanion copyWith({
    Value<String>? trackId,
    Value<int>? sequence,
    Value<int>? timestampMs,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return LibraryLyricsCompanion(
      trackId: trackId ?? this.trackId,
      sequence: sequence ?? this.sequence,
      timestampMs: timestampMs ?? this.timestampMs,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryLyricsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('sequence: $sequence, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDatabase extends GeneratedDatabase {
  _$LibraryDatabase(QueryExecutor e) : super(e);
  $LibraryDatabaseManager get managers => $LibraryDatabaseManager(this);
  late final $LibrarySourcesTable librarySources = $LibrarySourcesTable(this);
  late final $LibraryArtistsTable libraryArtists = $LibraryArtistsTable(this);
  late final $LibraryAlbumsTable libraryAlbums = $LibraryAlbumsTable(this);
  late final $LibraryTracksTable libraryTracks = $LibraryTracksTable(this);
  late final $LibraryLyricsTable libraryLyrics = $LibraryLyricsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    librarySources,
    libraryArtists,
    libraryAlbums,
    libraryTracks,
    libraryLyrics,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_artists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_albums', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_albums', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_albums',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_tracks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_tracks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_lyrics', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LibrarySourcesTableCreateCompanionBuilder =
    LibrarySourcesCompanion Function({
      required String id,
      required String type,
      required String displayName,
      required String rootUri,
      Value<Uint8List?> permissionBookmark,
      required String status,
      Value<int> scanRevision,
      Value<DateTime?> lastScanStartedAt,
      Value<DateTime?> lastScanCompletedAt,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LibrarySourcesTableUpdateCompanionBuilder =
    LibrarySourcesCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> displayName,
      Value<String> rootUri,
      Value<Uint8List?> permissionBookmark,
      Value<String> status,
      Value<int> scanRevision,
      Value<DateTime?> lastScanStartedAt,
      Value<DateTime?> lastScanCompletedAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LibrarySourcesTableReferences
    extends
        BaseReferences<_$LibraryDatabase, $LibrarySourcesTable, LibrarySource> {
  $$LibrarySourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LibraryArtistsTable, List<LibraryArtist>>
  _libraryArtistsRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryArtists,
        aliasName: 'library_sources__id__library_artists__source_id',
      );

  $$LibraryArtistsTableProcessedTableManager get libraryArtistsRefs {
    final manager = $$LibraryArtistsTableTableManager(
      $_db,
      $_db.libraryArtists,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryArtistsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LibraryAlbumsTable, List<LibraryAlbum>>
  _libraryAlbumsRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryAlbums,
        aliasName: 'library_sources__id__library_albums__source_id',
      );

  $$LibraryAlbumsTableProcessedTableManager get libraryAlbumsRefs {
    final manager = $$LibraryAlbumsTableTableManager(
      $_db,
      $_db.libraryAlbums,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryAlbumsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LibraryTracksTable, List<LibraryTrack>>
  _libraryTracksRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryTracks,
        aliasName: 'library_sources__id__library_tracks__source_id',
      );

  $$LibraryTracksTableProcessedTableManager get libraryTracksRefs {
    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibrarySourcesTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibrarySourcesTable> {
  $$LibrarySourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootUri => $composableBuilder(
    column: $table.rootUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get permissionBookmark => $composableBuilder(
    column: $table.permissionBookmark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scanRevision => $composableBuilder(
    column: $table.scanRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScanStartedAt => $composableBuilder(
    column: $table.lastScanStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScanCompletedAt => $composableBuilder(
    column: $table.lastScanCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> libraryArtistsRefs(
    Expression<bool> Function($$LibraryArtistsTableFilterComposer f) f,
  ) {
    final $$LibraryArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableFilterComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> libraryAlbumsRefs(
    Expression<bool> Function($$LibraryAlbumsTableFilterComposer f) f,
  ) {
    final $$LibraryAlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryAlbums,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryAlbumsTableFilterComposer(
            $db: $db,
            $table: $db.libraryAlbums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> libraryTracksRefs(
    Expression<bool> Function($$LibraryTracksTableFilterComposer f) f,
  ) {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibrarySourcesTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibrarySourcesTable> {
  $$LibrarySourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootUri => $composableBuilder(
    column: $table.rootUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get permissionBookmark => $composableBuilder(
    column: $table.permissionBookmark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scanRevision => $composableBuilder(
    column: $table.scanRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScanStartedAt => $composableBuilder(
    column: $table.lastScanStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScanCompletedAt => $composableBuilder(
    column: $table.lastScanCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibrarySourcesTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibrarySourcesTable> {
  $$LibrarySourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootUri =>
      $composableBuilder(column: $table.rootUri, builder: (column) => column);

  GeneratedColumn<Uint8List> get permissionBookmark => $composableBuilder(
    column: $table.permissionBookmark,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get scanRevision => $composableBuilder(
    column: $table.scanRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastScanStartedAt => $composableBuilder(
    column: $table.lastScanStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastScanCompletedAt => $composableBuilder(
    column: $table.lastScanCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> libraryArtistsRefs<T extends Object>(
    Expression<T> Function($$LibraryArtistsTableAnnotationComposer a) f,
  ) {
    final $$LibraryArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> libraryAlbumsRefs<T extends Object>(
    Expression<T> Function($$LibraryAlbumsTableAnnotationComposer a) f,
  ) {
    final $$LibraryAlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryAlbums,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryAlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryAlbums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> libraryTracksRefs<T extends Object>(
    Expression<T> Function($$LibraryTracksTableAnnotationComposer a) f,
  ) {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibrarySourcesTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibrarySourcesTable,
          LibrarySource,
          $$LibrarySourcesTableFilterComposer,
          $$LibrarySourcesTableOrderingComposer,
          $$LibrarySourcesTableAnnotationComposer,
          $$LibrarySourcesTableCreateCompanionBuilder,
          $$LibrarySourcesTableUpdateCompanionBuilder,
          (LibrarySource, $$LibrarySourcesTableReferences),
          LibrarySource,
          PrefetchHooks Function({
            bool libraryArtistsRefs,
            bool libraryAlbumsRefs,
            bool libraryTracksRefs,
          })
        > {
  $$LibrarySourcesTableTableManager(
    _$LibraryDatabase db,
    $LibrarySourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibrarySourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibrarySourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibrarySourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> rootUri = const Value.absent(),
                Value<Uint8List?> permissionBookmark = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> scanRevision = const Value.absent(),
                Value<DateTime?> lastScanStartedAt = const Value.absent(),
                Value<DateTime?> lastScanCompletedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibrarySourcesCompanion(
                id: id,
                type: type,
                displayName: displayName,
                rootUri: rootUri,
                permissionBookmark: permissionBookmark,
                status: status,
                scanRevision: scanRevision,
                lastScanStartedAt: lastScanStartedAt,
                lastScanCompletedAt: lastScanCompletedAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String displayName,
                required String rootUri,
                Value<Uint8List?> permissionBookmark = const Value.absent(),
                required String status,
                Value<int> scanRevision = const Value.absent(),
                Value<DateTime?> lastScanStartedAt = const Value.absent(),
                Value<DateTime?> lastScanCompletedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LibrarySourcesCompanion.insert(
                id: id,
                type: type,
                displayName: displayName,
                rootUri: rootUri,
                permissionBookmark: permissionBookmark,
                status: status,
                scanRevision: scanRevision,
                lastScanStartedAt: lastScanStartedAt,
                lastScanCompletedAt: lastScanCompletedAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibrarySourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                libraryArtistsRefs = false,
                libraryAlbumsRefs = false,
                libraryTracksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryArtistsRefs) db.libraryArtists,
                    if (libraryAlbumsRefs) db.libraryAlbums,
                    if (libraryTracksRefs) db.libraryTracks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryArtistsRefs)
                        await $_getPrefetchedData<
                          LibrarySource,
                          $LibrarySourcesTable,
                          LibraryArtist
                        >(
                          currentTable: table,
                          referencedTable: $$LibrarySourcesTableReferences
                              ._libraryArtistsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibrarySourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryArtistsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (libraryAlbumsRefs)
                        await $_getPrefetchedData<
                          LibrarySource,
                          $LibrarySourcesTable,
                          LibraryAlbum
                        >(
                          currentTable: table,
                          referencedTable: $$LibrarySourcesTableReferences
                              ._libraryAlbumsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibrarySourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryAlbumsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (libraryTracksRefs)
                        await $_getPrefetchedData<
                          LibrarySource,
                          $LibrarySourcesTable,
                          LibraryTrack
                        >(
                          currentTable: table,
                          referencedTable: $$LibrarySourcesTableReferences
                              ._libraryTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibrarySourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibrarySourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibrarySourcesTable,
      LibrarySource,
      $$LibrarySourcesTableFilterComposer,
      $$LibrarySourcesTableOrderingComposer,
      $$LibrarySourcesTableAnnotationComposer,
      $$LibrarySourcesTableCreateCompanionBuilder,
      $$LibrarySourcesTableUpdateCompanionBuilder,
      (LibrarySource, $$LibrarySourcesTableReferences),
      LibrarySource,
      PrefetchHooks Function({
        bool libraryArtistsRefs,
        bool libraryAlbumsRefs,
        bool libraryTracksRefs,
      })
    >;
typedef $$LibraryArtistsTableCreateCompanionBuilder =
    LibraryArtistsCompanion Function({
      required String id,
      required String sourceId,
      required String name,
      required String sortName,
      Value<int> rowid,
    });
typedef $$LibraryArtistsTableUpdateCompanionBuilder =
    LibraryArtistsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> name,
      Value<String> sortName,
      Value<int> rowid,
    });

final class $$LibraryArtistsTableReferences
    extends
        BaseReferences<_$LibraryDatabase, $LibraryArtistsTable, LibraryArtist> {
  $$LibraryArtistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibrarySourcesTable _sourceIdTable(_$LibraryDatabase db) => db
      .librarySources
      .createAlias('library_artists__source_id__library_sources__id');

  $$LibrarySourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$LibrarySourcesTableTableManager(
      $_db,
      $_db.librarySources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LibraryAlbumsTable, List<LibraryAlbum>>
  _libraryAlbumsRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryAlbums,
        aliasName: 'library_artists__id__library_albums__artist_id',
      );

  $$LibraryAlbumsTableProcessedTableManager get libraryAlbumsRefs {
    final manager = $$LibraryAlbumsTableTableManager(
      $_db,
      $_db.libraryAlbums,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryAlbumsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LibraryTracksTable, List<LibraryTrack>>
  _libraryTracksRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryTracks,
        aliasName: 'library_artists__id__library_tracks__artist_id',
      );

  $$LibraryTracksTableProcessedTableManager get libraryTracksRefs {
    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryArtistsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibraryArtistsTable> {
  $$LibraryArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortName => $composableBuilder(
    column: $table.sortName,
    builder: (column) => ColumnFilters(column),
  );

  $$LibrarySourcesTableFilterComposer get sourceId {
    final $$LibrarySourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableFilterComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> libraryAlbumsRefs(
    Expression<bool> Function($$LibraryAlbumsTableFilterComposer f) f,
  ) {
    final $$LibraryAlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryAlbums,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryAlbumsTableFilterComposer(
            $db: $db,
            $table: $db.libraryAlbums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> libraryTracksRefs(
    Expression<bool> Function($$LibraryTracksTableFilterComposer f) f,
  ) {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryArtistsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibraryArtistsTable> {
  $$LibraryArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortName => $composableBuilder(
    column: $table.sortName,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibrarySourcesTableOrderingComposer get sourceId {
    final $$LibrarySourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableOrderingComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryArtistsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibraryArtistsTable> {
  $$LibraryArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sortName =>
      $composableBuilder(column: $table.sortName, builder: (column) => column);

  $$LibrarySourcesTableAnnotationComposer get sourceId {
    final $$LibrarySourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> libraryAlbumsRefs<T extends Object>(
    Expression<T> Function($$LibraryAlbumsTableAnnotationComposer a) f,
  ) {
    final $$LibraryAlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryAlbums,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryAlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryAlbums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> libraryTracksRefs<T extends Object>(
    Expression<T> Function($$LibraryTracksTableAnnotationComposer a) f,
  ) {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryArtistsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibraryArtistsTable,
          LibraryArtist,
          $$LibraryArtistsTableFilterComposer,
          $$LibraryArtistsTableOrderingComposer,
          $$LibraryArtistsTableAnnotationComposer,
          $$LibraryArtistsTableCreateCompanionBuilder,
          $$LibraryArtistsTableUpdateCompanionBuilder,
          (LibraryArtist, $$LibraryArtistsTableReferences),
          LibraryArtist,
          PrefetchHooks Function({
            bool sourceId,
            bool libraryAlbumsRefs,
            bool libraryTracksRefs,
          })
        > {
  $$LibraryArtistsTableTableManager(
    _$LibraryDatabase db,
    $LibraryArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sortName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryArtistsCompanion(
                id: id,
                sourceId: sourceId,
                name: name,
                sortName: sortName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String name,
                required String sortName,
                Value<int> rowid = const Value.absent(),
              }) => LibraryArtistsCompanion.insert(
                id: id,
                sourceId: sourceId,
                name: name,
                sortName: sortName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                libraryAlbumsRefs = false,
                libraryTracksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryAlbumsRefs) db.libraryAlbums,
                    if (libraryTracksRefs) db.libraryTracks,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sourceId,
                                    referencedTable:
                                        $$LibraryArtistsTableReferences
                                            ._sourceIdTable(db),
                                    referencedColumn:
                                        $$LibraryArtistsTableReferences
                                            ._sourceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryAlbumsRefs)
                        await $_getPrefetchedData<
                          LibraryArtist,
                          $LibraryArtistsTable,
                          LibraryAlbum
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryArtistsTableReferences
                              ._libraryAlbumsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryArtistsTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryAlbumsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.artistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (libraryTracksRefs)
                        await $_getPrefetchedData<
                          LibraryArtist,
                          $LibraryArtistsTable,
                          LibraryTrack
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryArtistsTableReferences
                              ._libraryTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryArtistsTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.artistId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibraryArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibraryArtistsTable,
      LibraryArtist,
      $$LibraryArtistsTableFilterComposer,
      $$LibraryArtistsTableOrderingComposer,
      $$LibraryArtistsTableAnnotationComposer,
      $$LibraryArtistsTableCreateCompanionBuilder,
      $$LibraryArtistsTableUpdateCompanionBuilder,
      (LibraryArtist, $$LibraryArtistsTableReferences),
      LibraryArtist,
      PrefetchHooks Function({
        bool sourceId,
        bool libraryAlbumsRefs,
        bool libraryTracksRefs,
      })
    >;
typedef $$LibraryAlbumsTableCreateCompanionBuilder =
    LibraryAlbumsCompanion Function({
      required String id,
      required String sourceId,
      Value<String?> artistId,
      required String title,
      required String sortTitle,
      required String albumArtist,
      Value<int?> year,
      Value<String?> genre,
      Value<String?> artworkKey,
      Value<int> rowid,
    });
typedef $$LibraryAlbumsTableUpdateCompanionBuilder =
    LibraryAlbumsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String?> artistId,
      Value<String> title,
      Value<String> sortTitle,
      Value<String> albumArtist,
      Value<int?> year,
      Value<String?> genre,
      Value<String?> artworkKey,
      Value<int> rowid,
    });

final class $$LibraryAlbumsTableReferences
    extends
        BaseReferences<_$LibraryDatabase, $LibraryAlbumsTable, LibraryAlbum> {
  $$LibraryAlbumsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibrarySourcesTable _sourceIdTable(_$LibraryDatabase db) => db
      .librarySources
      .createAlias('library_albums__source_id__library_sources__id');

  $$LibrarySourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$LibrarySourcesTableTableManager(
      $_db,
      $_db.librarySources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LibraryArtistsTable _artistIdTable(_$LibraryDatabase db) => db
      .libraryArtists
      .createAlias('library_albums__artist_id__library_artists__id');

  $$LibraryArtistsTableProcessedTableManager? get artistId {
    final $_column = $_itemColumn<String>('artist_id');
    if ($_column == null) return null;
    final manager = $$LibraryArtistsTableTableManager(
      $_db,
      $_db.libraryArtists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LibraryTracksTable, List<LibraryTrack>>
  _libraryTracksRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryTracks,
        aliasName: 'library_albums__id__library_tracks__album_id',
      );

  $$LibraryTracksTableProcessedTableManager get libraryTracksRefs {
    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.albumId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryAlbumsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibraryAlbumsTable> {
  $$LibraryAlbumsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkKey => $composableBuilder(
    column: $table.artworkKey,
    builder: (column) => ColumnFilters(column),
  );

  $$LibrarySourcesTableFilterComposer get sourceId {
    final $$LibrarySourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableFilterComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableFilterComposer get artistId {
    final $$LibraryArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableFilterComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> libraryTracksRefs(
    Expression<bool> Function($$LibraryTracksTableFilterComposer f) f,
  ) {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryAlbumsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibraryAlbumsTable> {
  $$LibraryAlbumsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkKey => $composableBuilder(
    column: $table.artworkKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibrarySourcesTableOrderingComposer get sourceId {
    final $$LibrarySourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableOrderingComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableOrderingComposer get artistId {
    final $$LibraryArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryAlbumsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibraryAlbumsTable> {
  $$LibraryAlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sortTitle =>
      $composableBuilder(column: $table.sortTitle, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get artworkKey => $composableBuilder(
    column: $table.artworkKey,
    builder: (column) => column,
  );

  $$LibrarySourcesTableAnnotationComposer get sourceId {
    final $$LibrarySourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableAnnotationComposer get artistId {
    final $$LibraryArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> libraryTracksRefs<T extends Object>(
    Expression<T> Function($$LibraryTracksTableAnnotationComposer a) f,
  ) {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryAlbumsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibraryAlbumsTable,
          LibraryAlbum,
          $$LibraryAlbumsTableFilterComposer,
          $$LibraryAlbumsTableOrderingComposer,
          $$LibraryAlbumsTableAnnotationComposer,
          $$LibraryAlbumsTableCreateCompanionBuilder,
          $$LibraryAlbumsTableUpdateCompanionBuilder,
          (LibraryAlbum, $$LibraryAlbumsTableReferences),
          LibraryAlbum,
          PrefetchHooks Function({
            bool sourceId,
            bool artistId,
            bool libraryTracksRefs,
          })
        > {
  $$LibraryAlbumsTableTableManager(
    _$LibraryDatabase db,
    $LibraryAlbumsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryAlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryAlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryAlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> artistId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sortTitle = const Value.absent(),
                Value<String> albumArtist = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> artworkKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryAlbumsCompanion(
                id: id,
                sourceId: sourceId,
                artistId: artistId,
                title: title,
                sortTitle: sortTitle,
                albumArtist: albumArtist,
                year: year,
                genre: genre,
                artworkKey: artworkKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                Value<String?> artistId = const Value.absent(),
                required String title,
                required String sortTitle,
                required String albumArtist,
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> artworkKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryAlbumsCompanion.insert(
                id: id,
                sourceId: sourceId,
                artistId: artistId,
                title: title,
                sortTitle: sortTitle,
                albumArtist: albumArtist,
                year: year,
                genre: genre,
                artworkKey: artworkKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryAlbumsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                artistId = false,
                libraryTracksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryTracksRefs) db.libraryTracks,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sourceId,
                                    referencedTable:
                                        $$LibraryAlbumsTableReferences
                                            ._sourceIdTable(db),
                                    referencedColumn:
                                        $$LibraryAlbumsTableReferences
                                            ._sourceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (artistId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.artistId,
                                    referencedTable:
                                        $$LibraryAlbumsTableReferences
                                            ._artistIdTable(db),
                                    referencedColumn:
                                        $$LibraryAlbumsTableReferences
                                            ._artistIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryTracksRefs)
                        await $_getPrefetchedData<
                          LibraryAlbum,
                          $LibraryAlbumsTable,
                          LibraryTrack
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryAlbumsTableReferences
                              ._libraryTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryAlbumsTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.albumId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibraryAlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibraryAlbumsTable,
      LibraryAlbum,
      $$LibraryAlbumsTableFilterComposer,
      $$LibraryAlbumsTableOrderingComposer,
      $$LibraryAlbumsTableAnnotationComposer,
      $$LibraryAlbumsTableCreateCompanionBuilder,
      $$LibraryAlbumsTableUpdateCompanionBuilder,
      (LibraryAlbum, $$LibraryAlbumsTableReferences),
      LibraryAlbum,
      PrefetchHooks Function({
        bool sourceId,
        bool artistId,
        bool libraryTracksRefs,
      })
    >;
typedef $$LibraryTracksTableCreateCompanionBuilder =
    LibraryTracksCompanion Function({
      required String id,
      required String sourceId,
      Value<String?> albumId,
      Value<String?> artistId,
      required String relativePath,
      required String mediaUri,
      required String title,
      required String artistName,
      required String albumTitle,
      required int durationMs,
      Value<int> trackNumber,
      Value<int> discNumber,
      Value<int?> year,
      Value<String?> genre,
      Value<String?> contentType,
      Value<int?> fileSize,
      required DateTime modifiedAt,
      Value<String?> artworkKey,
      Value<int> rowid,
    });
typedef $$LibraryTracksTableUpdateCompanionBuilder =
    LibraryTracksCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String?> albumId,
      Value<String?> artistId,
      Value<String> relativePath,
      Value<String> mediaUri,
      Value<String> title,
      Value<String> artistName,
      Value<String> albumTitle,
      Value<int> durationMs,
      Value<int> trackNumber,
      Value<int> discNumber,
      Value<int?> year,
      Value<String?> genre,
      Value<String?> contentType,
      Value<int?> fileSize,
      Value<DateTime> modifiedAt,
      Value<String?> artworkKey,
      Value<int> rowid,
    });

final class $$LibraryTracksTableReferences
    extends
        BaseReferences<_$LibraryDatabase, $LibraryTracksTable, LibraryTrack> {
  $$LibraryTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibrarySourcesTable _sourceIdTable(_$LibraryDatabase db) => db
      .librarySources
      .createAlias('library_tracks__source_id__library_sources__id');

  $$LibrarySourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$LibrarySourcesTableTableManager(
      $_db,
      $_db.librarySources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LibraryAlbumsTable _albumIdTable(_$LibraryDatabase db) => db
      .libraryAlbums
      .createAlias('library_tracks__album_id__library_albums__id');

  $$LibraryAlbumsTableProcessedTableManager? get albumId {
    final $_column = $_itemColumn<String>('album_id');
    if ($_column == null) return null;
    final manager = $$LibraryAlbumsTableTableManager(
      $_db,
      $_db.libraryAlbums,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_albumIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LibraryArtistsTable _artistIdTable(_$LibraryDatabase db) => db
      .libraryArtists
      .createAlias('library_tracks__artist_id__library_artists__id');

  $$LibraryArtistsTableProcessedTableManager? get artistId {
    final $_column = $_itemColumn<String>('artist_id');
    if ($_column == null) return null;
    final manager = $$LibraryArtistsTableTableManager(
      $_db,
      $_db.libraryArtists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LibraryLyricsTable, List<LibraryLyric>>
  _libraryLyricsRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryLyrics,
        aliasName: 'library_tracks__id__library_lyrics__track_id',
      );

  $$LibraryLyricsTableProcessedTableManager get libraryLyricsRefs {
    final manager = $$LibraryLyricsTableTableManager(
      $_db,
      $_db.libraryLyrics,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryLyricsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryTracksTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUri => $composableBuilder(
    column: $table.mediaUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumTitle => $composableBuilder(
    column: $table.albumTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkKey => $composableBuilder(
    column: $table.artworkKey,
    builder: (column) => ColumnFilters(column),
  );

  $$LibrarySourcesTableFilterComposer get sourceId {
    final $$LibrarySourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableFilterComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryAlbumsTableFilterComposer get albumId {
    final $$LibraryAlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.libraryAlbums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryAlbumsTableFilterComposer(
            $db: $db,
            $table: $db.libraryAlbums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableFilterComposer get artistId {
    final $$LibraryArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableFilterComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> libraryLyricsRefs(
    Expression<bool> Function($$LibraryLyricsTableFilterComposer f) f,
  ) {
    final $$LibraryLyricsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryLyrics,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryLyricsTableFilterComposer(
            $db: $db,
            $table: $db.libraryLyrics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryTracksTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUri => $composableBuilder(
    column: $table.mediaUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumTitle => $composableBuilder(
    column: $table.albumTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkKey => $composableBuilder(
    column: $table.artworkKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibrarySourcesTableOrderingComposer get sourceId {
    final $$LibrarySourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableOrderingComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryAlbumsTableOrderingComposer get albumId {
    final $$LibraryAlbumsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.libraryAlbums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryAlbumsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryAlbums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableOrderingComposer get artistId {
    final $$LibraryArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTracksTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaUri =>
      $composableBuilder(column: $table.mediaUri, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumTitle => $composableBuilder(
    column: $table.albumTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkKey => $composableBuilder(
    column: $table.artworkKey,
    builder: (column) => column,
  );

  $$LibrarySourcesTableAnnotationComposer get sourceId {
    final $$LibrarySourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.librarySources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.librarySources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryAlbumsTableAnnotationComposer get albumId {
    final $$LibraryAlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.libraryAlbums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryAlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryAlbums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableAnnotationComposer get artistId {
    final $$LibraryArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> libraryLyricsRefs<T extends Object>(
    Expression<T> Function($$LibraryLyricsTableAnnotationComposer a) f,
  ) {
    final $$LibraryLyricsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryLyrics,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryLyricsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryLyrics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryTracksTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibraryTracksTable,
          LibraryTrack,
          $$LibraryTracksTableFilterComposer,
          $$LibraryTracksTableOrderingComposer,
          $$LibraryTracksTableAnnotationComposer,
          $$LibraryTracksTableCreateCompanionBuilder,
          $$LibraryTracksTableUpdateCompanionBuilder,
          (LibraryTrack, $$LibraryTracksTableReferences),
          LibraryTrack,
          PrefetchHooks Function({
            bool sourceId,
            bool albumId,
            bool artistId,
            bool libraryLyricsRefs,
          })
        > {
  $$LibraryTracksTableTableManager(
    _$LibraryDatabase db,
    $LibraryTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> albumId = const Value.absent(),
                Value<String?> artistId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> mediaUri = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<String> albumTitle = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> trackNumber = const Value.absent(),
                Value<int> discNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<String?> artworkKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryTracksCompanion(
                id: id,
                sourceId: sourceId,
                albumId: albumId,
                artistId: artistId,
                relativePath: relativePath,
                mediaUri: mediaUri,
                title: title,
                artistName: artistName,
                albumTitle: albumTitle,
                durationMs: durationMs,
                trackNumber: trackNumber,
                discNumber: discNumber,
                year: year,
                genre: genre,
                contentType: contentType,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                artworkKey: artworkKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                Value<String?> albumId = const Value.absent(),
                Value<String?> artistId = const Value.absent(),
                required String relativePath,
                required String mediaUri,
                required String title,
                required String artistName,
                required String albumTitle,
                required int durationMs,
                Value<int> trackNumber = const Value.absent(),
                Value<int> discNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                required DateTime modifiedAt,
                Value<String?> artworkKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryTracksCompanion.insert(
                id: id,
                sourceId: sourceId,
                albumId: albumId,
                artistId: artistId,
                relativePath: relativePath,
                mediaUri: mediaUri,
                title: title,
                artistName: artistName,
                albumTitle: albumTitle,
                durationMs: durationMs,
                trackNumber: trackNumber,
                discNumber: discNumber,
                year: year,
                genre: genre,
                contentType: contentType,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                artworkKey: artworkKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                albumId = false,
                artistId = false,
                libraryLyricsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryLyricsRefs) db.libraryLyrics,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sourceId,
                                    referencedTable:
                                        $$LibraryTracksTableReferences
                                            ._sourceIdTable(db),
                                    referencedColumn:
                                        $$LibraryTracksTableReferences
                                            ._sourceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (albumId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.albumId,
                                    referencedTable:
                                        $$LibraryTracksTableReferences
                                            ._albumIdTable(db),
                                    referencedColumn:
                                        $$LibraryTracksTableReferences
                                            ._albumIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (artistId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.artistId,
                                    referencedTable:
                                        $$LibraryTracksTableReferences
                                            ._artistIdTable(db),
                                    referencedColumn:
                                        $$LibraryTracksTableReferences
                                            ._artistIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryLyricsRefs)
                        await $_getPrefetchedData<
                          LibraryTrack,
                          $LibraryTracksTable,
                          LibraryLyric
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._libraryLyricsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryLyricsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibraryTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibraryTracksTable,
      LibraryTrack,
      $$LibraryTracksTableFilterComposer,
      $$LibraryTracksTableOrderingComposer,
      $$LibraryTracksTableAnnotationComposer,
      $$LibraryTracksTableCreateCompanionBuilder,
      $$LibraryTracksTableUpdateCompanionBuilder,
      (LibraryTrack, $$LibraryTracksTableReferences),
      LibraryTrack,
      PrefetchHooks Function({
        bool sourceId,
        bool albumId,
        bool artistId,
        bool libraryLyricsRefs,
      })
    >;
typedef $$LibraryLyricsTableCreateCompanionBuilder =
    LibraryLyricsCompanion Function({
      required String trackId,
      required int sequence,
      required int timestampMs,
      required String content,
      Value<int> rowid,
    });
typedef $$LibraryLyricsTableUpdateCompanionBuilder =
    LibraryLyricsCompanion Function({
      Value<String> trackId,
      Value<int> sequence,
      Value<int> timestampMs,
      Value<String> content,
      Value<int> rowid,
    });

final class $$LibraryLyricsTableReferences
    extends
        BaseReferences<_$LibraryDatabase, $LibraryLyricsTable, LibraryLyric> {
  $$LibraryLyricsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryTracksTable _trackIdTable(_$LibraryDatabase db) => db
      .libraryTracks
      .createAlias('library_lyrics__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LibraryLyricsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibraryLyricsTable> {
  $$LibraryLyricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryLyricsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibraryLyricsTable> {
  $$LibraryLyricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryLyricsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibraryLyricsTable> {
  $$LibraryLyricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryLyricsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibraryLyricsTable,
          LibraryLyric,
          $$LibraryLyricsTableFilterComposer,
          $$LibraryLyricsTableOrderingComposer,
          $$LibraryLyricsTableAnnotationComposer,
          $$LibraryLyricsTableCreateCompanionBuilder,
          $$LibraryLyricsTableUpdateCompanionBuilder,
          (LibraryLyric, $$LibraryLyricsTableReferences),
          LibraryLyric,
          PrefetchHooks Function({bool trackId})
        > {
  $$LibraryLyricsTableTableManager(
    _$LibraryDatabase db,
    $LibraryLyricsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryLyricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryLyricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryLyricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryLyricsCompanion(
                trackId: trackId,
                sequence: sequence,
                timestampMs: timestampMs,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                required int sequence,
                required int timestampMs,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => LibraryLyricsCompanion.insert(
                trackId: trackId,
                sequence: sequence,
                timestampMs: timestampMs,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryLyricsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable: $$LibraryLyricsTableReferences
                                    ._trackIdTable(db),
                                referencedColumn: $$LibraryLyricsTableReferences
                                    ._trackIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LibraryLyricsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibraryLyricsTable,
      LibraryLyric,
      $$LibraryLyricsTableFilterComposer,
      $$LibraryLyricsTableOrderingComposer,
      $$LibraryLyricsTableAnnotationComposer,
      $$LibraryLyricsTableCreateCompanionBuilder,
      $$LibraryLyricsTableUpdateCompanionBuilder,
      (LibraryLyric, $$LibraryLyricsTableReferences),
      LibraryLyric,
      PrefetchHooks Function({bool trackId})
    >;

class $LibraryDatabaseManager {
  final _$LibraryDatabase _db;
  $LibraryDatabaseManager(this._db);
  $$LibrarySourcesTableTableManager get librarySources =>
      $$LibrarySourcesTableTableManager(_db, _db.librarySources);
  $$LibraryArtistsTableTableManager get libraryArtists =>
      $$LibraryArtistsTableTableManager(_db, _db.libraryArtists);
  $$LibraryAlbumsTableTableManager get libraryAlbums =>
      $$LibraryAlbumsTableTableManager(_db, _db.libraryAlbums);
  $$LibraryTracksTableTableManager get libraryTracks =>
      $$LibraryTracksTableTableManager(_db, _db.libraryTracks);
  $$LibraryLyricsTableTableManager get libraryLyrics =>
      $$LibraryLyricsTableTableManager(_db, _db.libraryLyrics);
}
