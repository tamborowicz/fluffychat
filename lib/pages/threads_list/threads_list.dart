// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: threads navigation)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch on top of upstream FluffyChat: browse view for threads.
// Upstream keeps all the thread machinery (ChatController.enterThread plus the
// thread filter in filtered_timeline_extension.dart) but ships no browse view
// (upstream issue #2874). This page fills that gap.
//
// Source of truth is the server: GET /_matrix/client/v1/rooms/{roomId}/threads
// (Matrix 1.4, MSC3856). It returns thread roots from the *whole* room history
// with reply count and latest activity, paginated via from/next_batch - unlike
// a scan of ChatController.timeline, which only sees the loaded window
// (Room.defaultHistoryCount = 30 events plus 100 per scroll-to-top) and left
// threads invisible until the user manually paged back. When a homeserver does
// not implement that endpoint (M_UNRECOGNIZED / M_NOT_FOUND) the page degrades
// to the timeline scan.
//
// FORK RULE: import package:material_ui/material_ui.dart, never
// package:flutter/material.dart. FluffyChat v2 renders the whole app through
// material_ui, which ships its own ThemeData / Theme / ThemeMode and its own
// private inherited-theme widget. A widget from flutter/material.dart finds no
// Theme ancestor in this tree and silently falls back to ThemeData.fallback()
// (light #fffef7ff) whatever ThemeMode the user picked - that is exactly what
// made this page a glaring white window.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class ThreadsListPage extends StatefulWidget {
  final ChatController controller;

  const ThreadsListPage(this.controller, {super.key});

  @override
  State<ThreadsListPage> createState() => _ThreadsListPageState();
}

/// One row of the browse list, as delivered by /threads.
class _ThreadInfo {
  final String rootId;
  final int replyCount;
  final DateTime latestActivity;

  const _ThreadInfo({
    required this.rootId,
    required this.replyCount,
    required this.latestActivity,
  });
}

class _ThreadsListPageState extends State<ThreadsListPage> {
  static const int _pageSize = 20;

  final List<_ThreadInfo> _threads = [];
  final Set<String> _seenRoots = {};

  /// Root previews outside the loaded timeline are resolved once and cached
  /// (getEventById hits the local store, then the server, and decrypts).
  final Map<String, Future<Event?>> _rootLookups = {};

  String? _nextBatch;
  bool _firstLoad = true;
  bool _loadingMore = false;
  bool _serverUnsupported = false;
  String? _error;
  DateTime? _readMarkerTs;

  StreamSubscription<SyncUpdate>? _syncSubscription;

  Room get _room => widget.controller.room;

  bool get _hasMore => !_serverUnsupported && _nextBatch != null;

  @override
  void initState() {
    super.initState();
    // The page sits on top of the chat route, so nothing else rebuilds it when
    // something arrives through sync.
    _syncSubscription = _room.client.onSync.stream.listen((_) => _refresh());
    unawaited(_resolveReadMarker());
    unawaited(_loadMore());
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (_threads.isEmpty && !_loadingMore && !_firstLoad) {
      // A thread may have been started while this page was open and the empty
      // state is not scrollable, so pull-to-refresh is not available there.
      unawaited(_loadMore());
      return;
    }
    setState(() {});
  }

  /// Timestamp of the room's read marker, used to flag threads with newer
  /// activity. The homeserver does not expose per-thread unread state
  /// (MSC3773 is not advertised by e.g. matrix.org), so this is a local
  /// approximation.
  Future<void> _resolveReadMarker() async {
    final markerId = widget.controller.readMarkerEventId;
    if (markerId.isEmpty) return;
    try {
      final event =
          widget.controller.timeline?.events.firstWhereOrNull(
            (event) => event.eventId == markerId,
          ) ??
          await _room.getEventById(markerId);
      if (!mounted || event == null) return;
      setState(() => _readMarkerTs = event.originServerTs);
    } catch (_) {
      // No read marker available: no unread dots, no harm.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      if (_serverUnsupported) {
        _loadFromTimeline();
        return;
      }
      final response = await _room.client.request(
        RequestType.GET,
        '/client/v1/rooms/${_room.id}/threads',
        // 'include' only accepts 'all' (default) or 'participated'; anything
        // else is a 400.
        query: {'limit': '$_pageSize', 'from': ?_nextBatch},
      );
      final chunk = response['chunk'];
      if (chunk is List) {
        for (final raw in chunk) {
          if (raw is! Map) continue;
          final info = _parseThread(raw);
          if (info == null) continue;
          if (_seenRoots.add(info.rootId)) _threads.add(info);
        }
      }
      final nextBatch = response['next_batch'];
      _nextBatch = nextBatch is String && nextBatch.isNotEmpty
          ? nextBatch
          : null;
      _error = null;
    } on MatrixException catch (e) {
      if (e.errcode == 'M_UNRECOGNIZED' || e.errcode == 'M_NOT_FOUND') {
        // Homeserver without MSC3856: degrade to scanning the loaded timeline.
        _serverUnsupported = true;
        _loadFromTimeline();
      } else {
        _error = e.errorMessage;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingMore = false;
      if (mounted) {
        setState(() => _firstLoad = false);
      }
    }
  }

  _ThreadInfo? _parseThread(Map raw) {
    final rootId = raw['event_id'];
    if (rootId is! String) return null;
    final relations = (raw['unsigned'] as Map?)?['m.relations'] as Map?;
    final thread = relations?['m.thread'] as Map?;
    final latest = thread?['latest_event'] as Map?;
    final count = thread?['count'];
    final latestTs = latest?['origin_server_ts'];
    final rootTs = raw['origin_server_ts'];
    final ts = latestTs is int ? latestTs : (rootTs is int ? rootTs : 0);
    return _ThreadInfo(
      rootId: rootId,
      replyCount: count is int ? count : 0,
      latestActivity: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  /// Fallback for homeservers without /threads: group the thread replies of
  /// the loaded timeline by root.
  void _loadFromTimeline() {
    final replies = <String, List<Event>>{};
    for (final event in widget.controller.timeline?.events ?? const <Event>[]) {
      if (event.relationshipType != RelationshipTypes.thread) continue;
      final rootId = event.relationshipEventId;
      if (rootId == null) continue;
      (replies[rootId] ??= []).add(event);
    }
    final entries = replies.entries.toList()
      ..sort((a, b) => _latestTs(b.value).compareTo(_latestTs(a.value)));
    for (final entry in entries) {
      if (!_seenRoots.add(entry.key)) continue;
      _threads.add(
        _ThreadInfo(
          rootId: entry.key,
          replyCount: entry.value.length,
          latestActivity: _latestTs(entry.value),
        ),
      );
    }
    _nextBatch = null;
  }

  DateTime _latestTs(List<Event> replies) => replies
      .map((event) => event.originServerTs)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.thread),
        actions: [
          if (_loadingMore && !_firstLoad)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: MediaQuery(
        // Fork patch: 90% text, same as the room list (AppConfig.listTextScale).
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * AppConfig.listTextScale,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _reload,
          child: _buildBody(context, l10n, theme),
        ),
      ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _threads.clear();
      _seenRoots.clear();
      _rootLookups.clear();
      _nextBatch = null;
      _serverUnsupported = false;
      _firstLoad = true;
      _error = null;
    });
    await _loadMore();
  }

  Widget _buildBody(BuildContext context, L10n l10n, ThemeData theme) {
    if (_threads.isEmpty) {
      if (_firstLoad) {
        return const Center(child: CircularProgressIndicator());
      }
      final error = _error;
      if (error != null) {
        return ListView(
          children: [
            const SizedBox(height: 80),
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }
      return Center(
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
      );
    }
    return ListView.builder(
      itemCount: _threads.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _threads.length) {
          return ListTile(
            title: Text(l10n.loadMore, textAlign: TextAlign.center),
            onTap: _loadingMore ? null : () => unawaited(_loadMore()),
          );
        }
        final info = _threads[i];
        final unread =
            _readMarkerTs != null &&
            info.latestActivity.isAfter(_readMarkerTs!);
        return _buildTile(context, info: info, unread: unread);
      },
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required _ThreadInfo info,
    required bool unread,
  }) {
    final cachedRoot = widget.controller.timeline?.events.firstWhereOrNull(
      (event) => event.eventId == info.rootId,
    );
    if (cachedRoot != null) {
      return _ThreadTile(
        info: info,
        rootEvent: cachedRoot,
        unread: unread,
        onTap: () => _openThread(info.rootId),
      );
    }
    final lookup = _rootLookups.putIfAbsent(
      info.rootId,
      () => _room.getEventById(info.rootId),
    );
    return FutureBuilder<Event?>(
      future: lookup,
      builder: (context, snapshot) => _ThreadTile(
        info: info,
        rootEvent: snapshot.data,
        unread: unread,
        onTap: () => _openThread(info.rootId),
      ),
    );
  }

  void _openThread(String rootId) {
    final controller = widget.controller;
    Navigator.of(context).pop();
    controller.enterThread(rootId);
    // Pull the root into the timeline when it is older than the loaded window,
    // otherwise the thread view starts at the first reply with no context.
    // scrollToEventId reloads the timeline around the event (eventContextId)
    // when it cannot find it locally.
    if (controller.timeline != null) {
      unawaited(controller.scrollToEventId(rootId));
    }
  }
}

class _ThreadTile extends StatelessWidget {
  final _ThreadInfo info;
  final Event? rootEvent;
  final bool unread;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.info,
    required this.unread,
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
      key: ValueKey(info.rootId),
      leading: Badge(
        isLabelVisible: unread,
        child: Icon(
          Icons.forum_outlined,
          color: unread ? theme.colorScheme.primary : null,
        ),
      ),
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
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            l10n.countReplies(info.replyCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            info.latestActivity.localizedTimeShort(context),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
