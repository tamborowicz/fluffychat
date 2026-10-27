// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: threads navigation)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch on top of upstream FluffyChat: threads list page. Enumerates
// thread roots found in the loaded room timeline (m.thread relations),
// previews each root event and enters the thread on tap. Upstream keeps all
// thread machinery (enterThread / thread-filtered GUI) but has no browse view
// (upstream issue #2874) — this page fills that gap.

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ThreadsListPage extends StatelessWidget {
  final ChatController controller;

  const ThreadsListPage(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final timeline = controller.timeline;

    // Group thread replies by their root event id from the raw timeline
    // (thread replies arrive in the main timeline; the GUI filter only hides
    // them from view).
    final Map<String, List<Event>> threads = {};
    final Map<String, Event> eventsById = {};
    if (timeline != null) {
      for (final event in timeline.events) {
        eventsById[event.eventId] = event;
        if (event.relationshipType == RelationshipTypes.thread) {
          final rootId = event.relationshipEventId;
          if (rootId != null) {
            (threads[rootId] ??= []).add(event);
          }
        }
      }
    }

    // Most recently active thread first.
    final entries = threads.entries.toList()
      ..sort((a, b) => b.value.last.originServerTs.compareTo(a.value.last.originServerTs));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.thread)),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 48),
                  const SizedBox(height: 8),
                  Text(l10n.thread),
                ],
              ),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                return _ThreadTile(
                  controller: controller,
                  rootId: entry.key,
                  replyCount: entry.value.length,
                  rootEvent: eventsById[entry.key],
                );
              },
            ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatController controller;
  final String rootId;
  final int replyCount;
  final Event? rootEvent;

  const _ThreadTile({
    required this.controller,
    required this.rootId,
    required this.replyCount,
    this.rootEvent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FutureBuilder<Event?>(
      future: rootEvent != null
          ? Future<Event?>.value(rootEvent)
          : controller.room.getEventById(rootId),
      builder: (context, snapshot) {
        final event = snapshot.data;
        final senderName = event == null
            ? null
            : controller.room
                .unsafeGetUserFromMemoryOrFallback(event.senderId)
                .calcDisplayname();
        final preview = event
            ?.calcLocalizedBodyFallback(
              MatrixLocals(l10n),
              withSenderNamePrefix: true,
              hideReply: true,
            )
            .replaceAll('\n', ' ');
        return ListTile(
          leading: const Icon(Icons.forum_outlined),
          title: Text(
            event == null ? l10n.loadingPleaseWait : senderName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            preview ?? l10n.loadingPleaseWait,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text('$replyCount × ${l10n.reply}'),
          onTap: () {
            Navigator.of(context).pop();
            controller.enterThread(rootId);
          },
        );
      },
    );
  }
}