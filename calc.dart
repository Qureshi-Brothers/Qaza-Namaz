import 'package:adhan/adhan.dart';

const prayerKeys = ['fajr', 'zuhr', 'asr', 'maghrib', 'isha', 'witr'];

const prayerNames = {
  'fajr': 'Fajr',
  'zuhr': 'Zuhr',
  'asr': 'Asr',
  'maghrib': 'Maghrib',
  'isha': 'Isha',
  'witr': 'Witr',
};

class CalcInput {
  bool byAge = true; // true: baligh hone ki umar se, false: saalon ke andaze se
  double bulughAge = 15;
  double currentAge = 0;
  double prayedYears = 0; // un saalon ki tadaad jab namaz parhi
  double qazaYears = 0; // andaze se kitne saal ki qaza
  bool female = false;
  int haizDays = 6; // har mahine haiz ke din
  int children = 0;
  int nifasDays = 30; // har bache par nifas ke din
  bool includeRoza = true;
}

class CalcResult {
  final Map<String, int> prayers;
  final int roza;
  final double years;
  CalcResult(this.prayers, this.roza, this.years);
}

// Hisab: 1 saal = 365 din (ehtiyat), Ramadan = 30 roze.
// Aurat ke liye haiz aur nifas ke din minus hote hain.
// Roze mein sirf haiz minus hota hai (nifas ka faisla aalim se karwayen).
CalcResult calculate(CalcInput i) {
  double years = i.byAge ? (i.currentAge - i.bulughAge - i.prayedYears) : i.qazaYears;
  if (years < 0) years = 0;

  int days = (years * 365).round();
  int rozaDays = i.includeRoza ? (years * 30).round() : 0;

  if (i.female) {
    final haizTotal = (years * 12 * i.haizDays).round();
    final nifasTotal = i.children * i.nifasDays;
    days = days - haizTotal - nifasTotal;
    if (i.includeRoza) {
      rozaDays = rozaDays - (years * i.haizDays).round();
    }
  }
  if (days < 0) days = 0;
  if (rozaDays < 0) rozaDays = 0;

  final p = <String, int>{};
  for (final k in prayerKeys) {
    p[k] = days;
  }
  return CalcResult(p, rozaDays, years);
}

class PT {
  final String name;
  final DateTime time;
  final bool isPrayer;
  PT(this.name, this.time, this.isPrayer);
}

// Hanafi (Asr) aur Karachi method se namaz ke auqat, offline.
List<PT> prayerTimesFor(double lat, double lng, DateTime date) {
  final coords = Coordinates(lat, lng);
  final params = CalculationMethod.karachi.getParameters();
  params.madhab = Madhab.hanafi;
  final pt = PrayerTimes(
    coords,
    DateComponents(date.year, date.month, date.day),
    params,
  );
  return [
    PT('Fajr', pt.fajr.toLocal(), true),
    PT('Tulu-e-Aftab', pt.sunrise.toLocal(), false),
    PT('Zuhr', pt.dhuhr.toLocal(), true),
    PT('Asr', pt.asr.toLocal(), true),
    PT('Maghrib', pt.maghrib.toLocal(), true),
    PT('Isha', pt.isha.toLocal(), true),
  ];
}

String fmtTime(DateTime t) {
  final l = t.toLocal();
  int h = l.hour % 12;
  if (h == 0) h = 12;
  final m = l.minute.toString().padLeft(2, '0');
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}
