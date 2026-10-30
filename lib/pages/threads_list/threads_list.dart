// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: threads navigation)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch on top of upstream FluffyChat: browse view for threads.
// Upstream keeps all the thread machinery (ChatController.enterThread plus the
// thread filter in filtered_timeline_extension.dart) but ships no browse view
// (upstream issue #2874). This page lists the thread roots found in the room's
// loaded timeline (m.thread relations), previews them and enters the thread on
// tap.
//
// FORK RULE: import package:material_ui/material_ui.dart, never
// package:flutter/material.dart. FluffyChat v2 renders the whole app through
// material_ui, which ships its own ThemeData / Theme / ThemeMode and its own
// private inherited-theme widget. A widget from flutter/material.dart finds no
// Theme ancestor in this tree and silently falls back to ThemeData.fallback()
// (light #fffef7ff) whatever ThemeMode the user picked - that is exactly what
// made this page a glaring white window.

import 'dart:async';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class ThreadsListPage extends StatefulWidget {
  final ChatController controller;

  const ThreadsListPage(this.controller, {super.key});

  @override
  State<ThreadsListPage> createState() => _ThreadsListPageState();
}

class _ThreadsListPageState extends State<ThreadsListPage> {
  /// Thread roots outside the loaded timeline get resolved once and cached
  /// here; building those futures inside build() fires a database/server
  /// lookup again on every rebuild of every tile.
  final Map<String, Future<Event?>> _rootLookups = {};

  StreamSubscription<SyncUpdate>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    // This page sits on top of the chat route, so nothing else rebuilds it when
    // new thread replies arrive via sync. Follow the sync stream while open.
    _syncSubscription = widget.controller.room.client.onSync.stream.listen(
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    // Thread replies arrive in the main timeline; the GUI filter only hides
    // them from view. Group them by their root event id.
    final threads = <String, List<Event>>{};
    final eventsById = <String, Event>{};
    for (final event in widget.controller.timeline?.events ?? const <Event>[]) {
      eventsById[event.eventId] = event;
      if (event.relationshipType != RelationshipTypes.thread) continue;
      final rootId = event.relationshipEventId;
      if (rootId == null) continue;
      (threads[rootId] ??= []).add(event);
    }

    // Most recently active thread first.
    final entries = threads.entries.toList()
      ..sort((a, b) => _latestTs(b.value).compareTo(_latestTs(a.value)));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.thread)),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.nothingFound,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) => _buildTile(
                context,
                rootId: entries[i].key,
                replyCount: entries[i].value.length,
                rootEvent: eventsById[entries[i].key],
              ),
            ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String rootId,
    required int replyCount,
    Event? rootEvent,
  }) {
    if (rootEvent != null) {
      return _ThreadTile(
        rootId: rootId,
        replyCount: replyCount,
        onTap: () => _openThread(rootId),
        rootEvent: rootEvent,
      );
    }
    final lookup = _rootLookups.putIfAbsent(
      rootId,
      () => widget.controller.room.getEventById(rootId),
    );
    return FutureBuilder<Event?>(
      future: lookup,
      builder: (context, snapshot) => _ThreadTile(
        rootId: rootId,
        replyCount: replyCount,
        onTap: () => _openThread(rootId),
        rootEvent: snapshot.data,
      ),
    );
  }

  void _openThread(String rootId) {
    Navigator.of(context).pop();
    widget.controller.enterThread(rootId);
  }

  DateTime _latestTs(List<Event> replies) => replies
      .map((event) => event.originServerTs)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}

class _ThreadTile extends StatelessWidget {
  final String rootId;
  final int replyCount;
  final Event? rootEvent;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.rootId,
    required this.replyCount,
    required this.onTap,
    this.rootEvent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final event = rootEvent;
    String? senderName;
    if (event != null) {
      senderName = event.room
          .unsafeGetUserFromMemoryOrFallback(event.senderId)
          .calcDisplayname();
    }
    final preview = event
        ?.calcLocalizedBodyFallback(
          MatrixLocals(l10n),
          withSenderNamePrefix: true,
          hideReply: true,
        )
        .replaceAll('\n', ' ');

    return ListTile(
      key: ValueKey(rootId),
      leading: const Icon(Icons.forum_outlined),
      title: Text(
        senderName ?? l10n.loadingPleaseWait,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        preview ?? l10n.loadingPleaseWait,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        l10n.countReplies(replyCount),
        textAlign: TextAlign.end,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
    );
  }
}
