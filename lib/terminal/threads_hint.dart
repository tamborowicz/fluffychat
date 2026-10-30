// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: threads navigation)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch: keeps track of whether a room has threads so the chat app bar does
// not rescan the timeline on every rebuild, and probes the homeserver once per
// room (MSC3856 /threads) so the entry point also appears when every thread is
// older than the loaded timeline window. Lives here so upstream's chat.dart only
// carries the hook calls.

import 'package:matrix/matrix.dart';

class ThreadsHint {
  bool visible = false;

  static final Map<String, bool> _probeCache = {};

  /// Cheap local pass over the loaded timeline. Returns true when it flipped
  /// from "no threads" to "has threads".
  bool refresh(Timeline? timeline) {
    if (visible) return false;
    final hasThreads =
        timeline?.events.any(
          (event) => event.relationshipType == RelationshipTypes.thread,
        ) ??
        false;
    if (!hasThreads) return false;
    visible = true;
    return true;
  }

  /// One `GET /rooms/{id}/threads?limit=1` per room and app run. Silent no-op
  /// on homeservers without that endpoint or while offline.
  Future<void> probe(
    Room room, {
    required void Function() onThreadsFound,
  }) async {
    final roomId = room.id;
    final cached = _probeCache[roomId];
    if (cached != null) {
      if (cached && !visible) {
        visible = true;
        onThreadsFound();
      }
      return;
    }
    try {
      final response = await room.client.request(
        RequestType.GET,
        '/client/v1/rooms/$roomId/threads',
        query: {'limit': '1'},
      );
      final chunk = response['chunk'];
      final hasThreads = chunk is List && chunk.isNotEmpty;
      _probeCache[roomId] = hasThreads;
      if (hasThreads && !visible) {
        visible = true;
        onThreadsFound();
      }
    } catch (error, stackTrace) {
      Logs().v('Threads probe unavailable for $roomId', error, stackTrace);
    }
  }
}
