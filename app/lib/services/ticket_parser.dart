/// Best-guess extraction of a destination, departure time and PNR from the
/// free text of a shared ticket / booking confirmation. Deliberately fuzzy —
/// the Confirm screen lets the user correct anything before tracking starts.
class ParsedTicket {
  final String? destinationName;
  final String? pnr;
  final DateTime? departureAt;
  final String rawText;

  const ParsedTicket({
    this.destinationName,
    this.pnr,
    this.departureAt,
    required this.rawText,
  });

  bool get hasAnything =>
      destinationName != null || pnr != null || departureAt != null;
}

class TicketParser {
  TicketParser._();

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static ParsedTicket parse(String text) {
    final cleaned = text.replaceAll('\r', '\n');
    return ParsedTicket(
      rawText: text,
      pnr: _pnr(cleaned),
      destinationName: _destination(cleaned),
      departureAt: _departure(cleaned),
    );
  }

  /// A 10-digit PNR, preferably next to the word "PNR".
  static String? _pnr(String text) {
    final labelled = RegExp(r'PNR\s*(?:no\.?|number)?\s*[:\-]?\s*(\d{10})',
            caseSensitive: false)
        .firstMatch(text);
    if (labelled != null) return labelled.group(1);
    // Bare 10-digit only if the text mentions PNR somewhere (avoid phone nos.).
    if (RegExp(r'PNR', caseSensitive: false).hasMatch(text)) {
      final bare = RegExp(r'(?<!\d)(\d{10})(?!\d)').firstMatch(text);
      return bare?.group(1);
    }
    return null;
  }

  /// Extract a destination place name using common booking-text phrasings.
  static String? _destination(String text) {
    final patterns = <RegExp>[
      // "To: NEW DELHI (NDLS)" / "Destination: Jaipur Jn"
      RegExp(r'(?:destination|deboarding\s+at|alight(?:ing)?\s+at|arriving\s+at)\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,40})',
          caseSensitive: false),
      // "... To NEW DELHI (NDLS) ..." — station name before a code in parens.
      RegExp(r'\bto\s+([A-Za-z][A-Za-z .]{2,40})\s*\([A-Z]{2,5}\)',
          caseSensitive: false),
      // "From X to Y" — capture Y.
      RegExp(r'\bfrom\s+[A-Za-z][A-Za-z .]{2,40}\s+to\s+([A-Za-z][A-Za-z .]{2,40})',
          caseSensitive: false),
      // Arrow notation "X → Y" / "X -> Y".
      RegExp(r'(?:→|->)\s*([A-Za-z][A-Za-z .]{2,40})'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      final raw = m?.group(1);
      if (raw != null) {
        final cleaned = _cleanPlace(raw);
        if (cleaned.isNotEmpty) return cleaned;
      }
    }
    return null;
  }

  static String _cleanPlace(String raw) {
    var s = raw.trim();
    // A number usually starts a date/time — the place name ends before it.
    final digit = s.indexOf(RegExp(r'\d'));
    if (digit > 0) s = s.substring(0, digit);
    // Cut at connectors/temporal words that usually follow a place name.
    for (final stop in [
      ' on ', ' at ', ' tomorrow', ' today', ' tonight', ' next ',
      ' dep', ' arr', ' pnr', ' date'
    ]) {
      final i = s.toLowerCase().indexOf(stop);
      if (i > 0) s = s.substring(0, i);
    }
    s = s.replaceAll(RegExp(r'[,.;].*$'), '').trim();
    // Title-case a SHOUTING station name for display.
    if (s == s.toUpperCase()) {
      s = s
          .toLowerCase()
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
    }
    return s;
  }

  /// Parse a departure date + optional time from common formats.
  static DateTime? _departure(String text) {
    // e.g. "12 Jul 2026" / "12-Jul-2026" / "12 July". Scan all candidates and
    // take the first whose month token is real (skips e.g. "8 ADI").
    int? day, month, year;
    final dateRe = RegExp(r'(\d{1,2})[\s\-]*([A-Za-z]{3,9})[\s\-,]*(\d{4})?',
        caseSensitive: false);
    for (final dm in dateRe.allMatches(text)) {
      final mon = _months[dm.group(2)!.substring(0, 3).toLowerCase()];
      if (mon != null) {
        day = int.tryParse(dm.group(1)!);
        month = mon;
        year = int.tryParse(dm.group(3) ?? '') ?? DateTime.now().year;
        break;
      }
    }
    // Time "21:30" / "9:00 PM"
    int hour = 0, minute = 0;
    final tm = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false)
        .firstMatch(text);
    if (tm != null) {
      hour = int.tryParse(tm.group(1)!) ?? 0;
      minute = int.tryParse(tm.group(2)!) ?? 0;
      final ap = tm.group(3)?.toUpperCase();
      if (ap == 'PM' && hour < 12) hour += 12;
      if (ap == 'AM' && hour == 12) hour = 0;
    }
    if (day != null && month != null) {
      return DateTime(year!, month, day, hour, minute);
    }
    return null;
  }
}
