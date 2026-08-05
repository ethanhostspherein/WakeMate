import 'package:flutter_test/flutter_test.dart';
import 'package:wakemate/services/ticket_parser.dart';

void main() {
  group('TicketParser', () {
    test('extracts PNR, destination and departure from an IRCTC-style text', () {
      const text =
          'IRCTC: PNR 2841936750, Train 12958 ADI SJ RAJDHANI. '
          'From AHMEDABAD JN (ADI) To NEW DELHI (NDLS). '
          'Date of journey 12 Jul 2026, Departure 17:40.';
      final t = TicketParser.parse(text);
      expect(t.pnr, '2841936750');
      expect(t.destinationName, 'New Delhi');
      expect(t.departureAt, DateTime(2026, 7, 12, 17, 40));
    });

    test('parses "from X to Y" and 12-hour time', () {
      const text = 'Your bus from Jaipur to Kota departs 9:30 PM on 3 Aug.';
      final t = TicketParser.parse(text);
      expect(t.destinationName, 'Kota');
      expect(t.departureAt!.hour, 21);
      expect(t.departureAt!.minute, 30);
    });

    test('does not treat a bare phone number as a PNR', () {
      const text = 'Call us on 9876543210 for support.';
      final t = TicketParser.parse(text);
      expect(t.pnr, isNull);
    });

    test('handles arrow notation for destination', () {
      const text = 'Trip Mumbai -> Pune tomorrow';
      final t = TicketParser.parse(text);
      expect(t.destinationName, 'Pune');
    });

    test('reports nothing useful for unrelated text', () {
      final t = TicketParser.parse('hello world');
      expect(t.hasAnything, isFalse);
    });
  });
}
