// intl's DateFormat has no Kinyarwanda locale data (DateFormat.Hm('rw')
// throws "Invalid locale") and the Hm skeleton always renders 24h time
// regardless of locale anyway — so a manual formatter is both simpler and
// safe across every locale this app supports, including rw.
String formatHm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
