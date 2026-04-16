// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_database.dart';

// ignore_for_file: type=lint
class $LocalChatMessagesTable extends LocalChatMessages
    with TableInfo<$LocalChatMessagesTable, LocalChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _conversationKeyMeta = const VerificationMeta(
    'conversationKey',
  );
  @override
  late final GeneratedColumn<String> conversationKey = GeneratedColumn<String>(
    'conversation_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<int> senderId = GeneratedColumn<int>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiverIdMeta = const VerificationMeta(
    'receiverId',
  );
  @override
  late final GeneratedColumn<int> receiverId = GeneratedColumn<int>(
    'receiver_id',
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
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<String> nonce = GeneratedColumn<String>(
    'nonce',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationKey,
    senderId,
    receiverId,
    content,
    nonce,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_key')) {
      context.handle(
        _conversationKeyMeta,
        conversationKey.isAcceptableOrUnknown(
          data['conversation_key']!,
          _conversationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationKeyMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('receiver_id')) {
      context.handle(
        _receiverIdMeta,
        receiverId.isAcceptableOrUnknown(data['receiver_id']!, _receiverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiverIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      conversationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_key'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sender_id'],
      )!,
      receiverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receiver_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nonce'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalChatMessagesTable createAlias(String alias) {
    return $LocalChatMessagesTable(attachedDatabase, alias);
  }
}

class LocalChatMessage extends DataClass
    implements Insertable<LocalChatMessage> {
  final int id;
  final String conversationKey;
  final int senderId;
  final int receiverId;
  final String content;
  final String? nonce;
  final String createdAt;
  const LocalChatMessage({
    required this.id,
    required this.conversationKey,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.nonce,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_key'] = Variable<String>(conversationKey);
    map['sender_id'] = Variable<int>(senderId);
    map['receiver_id'] = Variable<int>(receiverId);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || nonce != null) {
      map['nonce'] = Variable<String>(nonce);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  LocalChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalChatMessagesCompanion(
      id: Value(id),
      conversationKey: Value(conversationKey),
      senderId: Value(senderId),
      receiverId: Value(receiverId),
      content: Value(content),
      nonce: nonce == null && nullToAbsent
          ? const Value.absent()
          : Value(nonce),
      createdAt: Value(createdAt),
    );
  }

  factory LocalChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChatMessage(
      id: serializer.fromJson<int>(json['id']),
      conversationKey: serializer.fromJson<String>(json['conversationKey']),
      senderId: serializer.fromJson<int>(json['senderId']),
      receiverId: serializer.fromJson<int>(json['receiverId']),
      content: serializer.fromJson<String>(json['content']),
      nonce: serializer.fromJson<String?>(json['nonce']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationKey': serializer.toJson<String>(conversationKey),
      'senderId': serializer.toJson<int>(senderId),
      'receiverId': serializer.toJson<int>(receiverId),
      'content': serializer.toJson<String>(content),
      'nonce': serializer.toJson<String?>(nonce),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  LocalChatMessage copyWith({
    int? id,
    String? conversationKey,
    int? senderId,
    int? receiverId,
    String? content,
    Value<String?> nonce = const Value.absent(),
    String? createdAt,
  }) => LocalChatMessage(
    id: id ?? this.id,
    conversationKey: conversationKey ?? this.conversationKey,
    senderId: senderId ?? this.senderId,
    receiverId: receiverId ?? this.receiverId,
    content: content ?? this.content,
    nonce: nonce.present ? nonce.value : this.nonce,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalChatMessage copyWithCompanion(LocalChatMessagesCompanion data) {
    return LocalChatMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationKey: data.conversationKey.present
          ? data.conversationKey.value
          : this.conversationKey,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      receiverId: data.receiverId.present
          ? data.receiverId.value
          : this.receiverId,
      content: data.content.present ? data.content.value : this.content,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChatMessage(')
          ..write('id: $id, ')
          ..write('conversationKey: $conversationKey, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('content: $content, ')
          ..write('nonce: $nonce, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationKey,
    senderId,
    receiverId,
    content,
    nonce,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChatMessage &&
          other.id == this.id &&
          other.conversationKey == this.conversationKey &&
          other.senderId == this.senderId &&
          other.receiverId == this.receiverId &&
          other.content == this.content &&
          other.nonce == this.nonce &&
          other.createdAt == this.createdAt);
}

class LocalChatMessagesCompanion extends UpdateCompanion<LocalChatMessage> {
  final Value<int> id;
  final Value<String> conversationKey;
  final Value<int> senderId;
  final Value<int> receiverId;
  final Value<String> content;
  final Value<String?> nonce;
  final Value<String> createdAt;
  const LocalChatMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationKey = const Value.absent(),
    this.senderId = const Value.absent(),
    this.receiverId = const Value.absent(),
    this.content = const Value.absent(),
    this.nonce = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalChatMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String conversationKey,
    required int senderId,
    required int receiverId,
    required String content,
    this.nonce = const Value.absent(),
    required String createdAt,
  }) : conversationKey = Value(conversationKey),
       senderId = Value(senderId),
       receiverId = Value(receiverId),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<LocalChatMessage> custom({
    Expression<int>? id,
    Expression<String>? conversationKey,
    Expression<int>? senderId,
    Expression<int>? receiverId,
    Expression<String>? content,
    Expression<String>? nonce,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationKey != null) 'conversation_key': conversationKey,
      if (senderId != null) 'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      if (content != null) 'content': content,
      if (nonce != null) 'nonce': nonce,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalChatMessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? conversationKey,
    Value<int>? senderId,
    Value<int>? receiverId,
    Value<String>? content,
    Value<String?>? nonce,
    Value<String>? createdAt,
  }) {
    return LocalChatMessagesCompanion(
      id: id ?? this.id,
      conversationKey: conversationKey ?? this.conversationKey,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      nonce: nonce ?? this.nonce,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationKey.present) {
      map['conversation_key'] = Variable<String>(conversationKey.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<int>(senderId.value);
    }
    if (receiverId.present) {
      map['receiver_id'] = Variable<int>(receiverId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<String>(nonce.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationKey: $conversationKey, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('content: $content, ')
          ..write('nonce: $nonce, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChatDatabase extends GeneratedDatabase {
  _$ChatDatabase(QueryExecutor e) : super(e);
  $ChatDatabaseManager get managers => $ChatDatabaseManager(this);
  late final $LocalChatMessagesTable localChatMessages =
      $LocalChatMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localChatMessages];
}

typedef $$LocalChatMessagesTableCreateCompanionBuilder =
    LocalChatMessagesCompanion Function({
      Value<int> id,
      required String conversationKey,
      required int senderId,
      required int receiverId,
      required String content,
      Value<String?> nonce,
      required String createdAt,
    });
typedef $$LocalChatMessagesTableUpdateCompanionBuilder =
    LocalChatMessagesCompanion Function({
      Value<int> id,
      Value<String> conversationKey,
      Value<int> senderId,
      Value<int> receiverId,
      Value<String> content,
      Value<String?> nonce,
      Value<String> createdAt,
    });

class $$LocalChatMessagesTableFilterComposer
    extends Composer<_$ChatDatabase, $LocalChatMessagesTable> {
  $$LocalChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationKey => $composableBuilder(
    column: $table.conversationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalChatMessagesTableOrderingComposer
    extends Composer<_$ChatDatabase, $LocalChatMessagesTable> {
  $$LocalChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationKey => $composableBuilder(
    column: $table.conversationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalChatMessagesTableAnnotationComposer
    extends Composer<_$ChatDatabase, $LocalChatMessagesTable> {
  $$LocalChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationKey => $composableBuilder(
    column: $table.conversationKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<int> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalChatMessagesTableTableManager
    extends
        RootTableManager<
          _$ChatDatabase,
          $LocalChatMessagesTable,
          LocalChatMessage,
          $$LocalChatMessagesTableFilterComposer,
          $$LocalChatMessagesTableOrderingComposer,
          $$LocalChatMessagesTableAnnotationComposer,
          $$LocalChatMessagesTableCreateCompanionBuilder,
          $$LocalChatMessagesTableUpdateCompanionBuilder,
          (
            LocalChatMessage,
            BaseReferences<
              _$ChatDatabase,
              $LocalChatMessagesTable,
              LocalChatMessage
            >,
          ),
          LocalChatMessage,
          PrefetchHooks Function()
        > {
  $$LocalChatMessagesTableTableManager(
    _$ChatDatabase db,
    $LocalChatMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalChatMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> conversationKey = const Value.absent(),
                Value<int> senderId = const Value.absent(),
                Value<int> receiverId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> nonce = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => LocalChatMessagesCompanion(
                id: id,
                conversationKey: conversationKey,
                senderId: senderId,
                receiverId: receiverId,
                content: content,
                nonce: nonce,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String conversationKey,
                required int senderId,
                required int receiverId,
                required String content,
                Value<String?> nonce = const Value.absent(),
                required String createdAt,
              }) => LocalChatMessagesCompanion.insert(
                id: id,
                conversationKey: conversationKey,
                senderId: senderId,
                receiverId: receiverId,
                content: content,
                nonce: nonce,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatDatabase,
      $LocalChatMessagesTable,
      LocalChatMessage,
      $$LocalChatMessagesTableFilterComposer,
      $$LocalChatMessagesTableOrderingComposer,
      $$LocalChatMessagesTableAnnotationComposer,
      $$LocalChatMessagesTableCreateCompanionBuilder,
      $$LocalChatMessagesTableUpdateCompanionBuilder,
      (
        LocalChatMessage,
        BaseReferences<
          _$ChatDatabase,
          $LocalChatMessagesTable,
          LocalChatMessage
        >,
      ),
      LocalChatMessage,
      PrefetchHooks Function()
    >;

class $ChatDatabaseManager {
  final _$ChatDatabase _db;
  $ChatDatabaseManager(this._db);
  $$LocalChatMessagesTableTableManager get localChatMessages =>
      $$LocalChatMessagesTableTableManager(_db, _db.localChatMessages);
}
