/// Where a trip originated. Lets the UI/analytics distinguish a hand-set trip
/// from one auto-detected via a shared ticket or a PNR lookup.
enum TripSource { manual, shared, pnr }
