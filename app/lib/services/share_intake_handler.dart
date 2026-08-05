import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../routing/app_router.dart';
import 'ticket_parser.dart';

/// Bridges Android's share sheet into WakeMate. Text shared into the app (a
/// booking confirmation, an email body, a ticket) is parsed into a
/// [ParsedTicket] and routed to the Confirm screen. Part of "Share-to-WakeMate".
class ShareIntakeHandler {
  ShareIntakeHandler._();
  static final ShareIntakeHandler instance = ShareIntakeHandler._();

  StreamSubscription? _sub;

  /// Extract shared text from a media payload (text/url arrive in `path`).
  static String? _textOf(List<SharedMediaFile> media) {
    for (final m in media) {
      if (m.type == SharedMediaType.text || m.type == SharedMediaType.url) {
        if (m.path.trim().isNotEmpty) return m.path;
      }
    }
    return null;
  }

  /// Cold-start share: returns the parsed ticket if the app was launched via a
  /// share, else null. Call from splash so it can route appropriately.
  Future<ParsedTicket?> takeInitial() async {
    try {
      final media = await ReceiveSharingIntent.instance.getInitialMedia();
      final text = _textOf(media);
      await ReceiveSharingIntent.instance.reset();
      if (text == null) return null;
      final ticket = TicketParser.parse(text);
      return ticket.hasAnything ? ticket : ParsedTicket(rawText: text);
    } catch (_) {
      return null;
    }
  }

  /// Warm shares while the app is already running — push the Confirm screen.
  void listen() {
    _sub ??= ReceiveSharingIntent.instance.getMediaStream().listen((media) {
      final text = _textOf(media);
      if (text == null) return;
      final ticket = TicketParser.parse(text);
      appRouter.push(Routes.sharedTrip, extra: ticket);
    }, onError: (_) {});
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
