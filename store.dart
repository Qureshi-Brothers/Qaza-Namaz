import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notify.dart';

bool cloudReady = false;

const cities = <String, List<double>>{
  'Karachi': [24.8607, 67.0011],
  'Lahore': [31.5204, 74.3587],
  'Islamabad': [33.6844, 73.0479],
  'Rawalpindi': [33.5651, 73.0169],
  'Peshawar': [34.0151, 71.5249],
  'Quetta': [30.1798, 66.9750],
  'Multan': [30.1575, 71.5249],
  'Faisalabad': [31.4504, 73.1350],
  'Hyderabad': [25.3960, 68.3578],
  'Sialkot': [32.4945, 74.5229],
  'Gujranwala': [32.1877, 74.1945],
};

int _n(dynamic v) => v is num ? v.toInt() : 0;

Map<String, int> _intMap(dynamic v) {
  final out = <String, int>{};
  if (v is Map) {
    v.forEach((k, val) {
      out[k.toString()] = _n(val);
    });
  }
  return out;
}

String dayKey(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

class AppState extends ChangeNotifier {
  Map<String, dynamic> d = {};
  static const _key = 'qaza_state_v1';

  // ---------- getters ----------
  String? get gender => d['gender'] as String?;
  bool get female => gender == 'female';
  bool get setupDone => d['setupDone'] == true;
  bool get remind => d['remind'] != false;
  double? get lat => (d['lat'] as num?)?.toDouble();
  double? get lng => (d['lng'] as num?)?.toDouble();
  String get city => (d['city'] as String?) ?? '';
  int get target {
    final t = _n(d['target']);
    return t < 1 ? 5 : t;
  }

  Map<String, int> get prayers => _intMap(d['prayers']);
  Map<String, int> get initial => _intMap(d['initial']);
  int get roza => _n(d['roza']);
  int get rozaInitial => _n(d['rozaInitial']);
  Map<String, int> get log => _intMap(d['log']);

  int get totalLeft => prayers.values.fold(0, (a, b) => a + b);
  int get totalInitial => initial.values.fold(0, (a, b) => a + b);
  int get doneTotal {
    final x = totalInitial - totalLeft;
    return x < 0 ? 0 : x;
  }

  int get todayDone => log[dayKey(DateTime.now())] ?? 0;

  double get progress {
    final ini = totalInitial;
    if (ini <= 0) return 1;
    final v = 1 - (totalLeft / ini);
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }

  // pichle 14 din ka roz ka average (jis din se parhna shuru kiya)
  double get avgPerDay {
    final l = log;
    final now = DateTime.now();
    int sum = 0;
    int span = 0;
    for (int i = 13; i >= 0; i--) {
      final k = dayKey(now.subtract(Duration(days: i)));
      final v = l[k] ?? 0;
      if (span == 0 && v == 0) continue;
      span++;
      sum += v;
    }
    return span == 0 ? 0 : sum / span;
  }

  String? get email => cloudReady ? Supabase.instance.client.auth.currentUser?.email : null;
  bool get loggedIn => cloudReady && Supabase.instance.client.auth.currentUser != null;

  // ---------- load / save ----------
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_key);
    if (s != null) {
      try {
        d = Map<String, dynamic>.from(jsonDecode(s) as Map);
      } catch (_) {
        d = {};
      }
    }
  }

  Future<void> save({bool push = true}) async {
    d['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(d));
    notifyListeners();
    if (push) {
      pushCloud();
    }
  }

  // ---------- online sync (Supabase) ----------
  Future<String?> pushCloud() async {
    if (!cloudReady) return null;
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) return null;
    try {
      await c.from('qaza_data').upsert({
        'user_id': u.id,
        'data': d,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return null;
    } catch (_) {
      return 'Online save nahi hua. Internet check karein.';
    }
  }

  // Login ke baad: online data le aao (agar naya ho), warna phone ka data upar bhej do.
  Future<void> afterLogin() async {
    if (!cloudReady) return;
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) return;
    try {
      final row = await c.from('qaza_data').select().eq('user_id', u.id).maybeSingle();
      if (row != null && row['data'] is Map) {
        final remote = Map<String, dynamic>.from(row['data'] as Map);
        final rt = _n(remote['updatedAt']);
        final lt = _n(d['updatedAt']);
        if (rt >= lt || !setupDone) {
          d = remote;
          await save(push: false);
          await rescheduleReminders();
          return;
        }
      }
      await pushCloud();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    await pushCloud();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    d = {};
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
    await Notifier.cancelAll();
    notifyListeners();
  }

  // ---------- changes ----------
  Future<void> setGender(String g) async {
    d['gender'] = g;
    await save();
  }

  Future<void> applyCounts(Map<String, int> p, int r) async {
    d['prayers'] = Map<String, int>.from(p);
    d['initial'] = Map<String, int>.from(p);
    d['roza'] = r;
    d['rozaInitial'] = r;
    d['setupDone'] = true;
    await save();
  }

  void _bumpLog(String name, int by) {
    final l = _intMap(d[name]);
    final k = dayKey(DateTime.now());
    final v = (l[k] ?? 0) + by;
    l[k] = v < 0 ? 0 : v;
    d[name] = l;
  }

  // delta = -1: parh li, +1: galti se ghata diya to wapas jama
  Future<void> changePrayer(String k, int delta) async {
    final p = prayers;
    final cur = p[k] ?? 0;
    if (delta < 0 && cur <= 0) return;
    p[k] = cur + delta;
    d['prayers'] = p;
    final ini = initial;
    if ((p[k] ?? 0) > (ini[k] ?? 0)) {
      ini[k] = p[k] ?? 0;
      d['initial'] = ini;
    }
    _bumpLog('log', delta < 0 ? 1 : -1);
    await save();
  }

  Future<void> changeRoza(int delta) async {
    final cur = roza;
    if (delta < 0 && cur <= 0) return;
    d['roza'] = cur + delta;
    if (cur + delta > rozaInitial) {
      d['rozaInitial'] = cur + delta;
    }
    _bumpLog('rozaLog', delta < 0 ? 1 : -1);
    await save();
  }

  Future<void> setTarget(int t) async {
    d['target'] = t < 1 ? 1 : t;
    await save();
  }

  Future<void> setRemind(bool v) async {
    d['remind'] = v;
    await save();
    await Notifier.askPermission();
    await rescheduleReminders();
  }

  Future<void> setCity(String name) async {
    final c = cities[name];
    if (c == null) return;
    d['city'] = name;
    d['lat'] = c[0];
    d['lng'] = c[1];
    await save();
    await rescheduleReminders();
  }

  // GPS se location. Kamyabi par null, warna masle ka paigham wapas.
  Future<String?> useGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return 'Phone ka GPS band hai, on karein.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return 'Location ki ijazat nahi mili. Shehar chun lein.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 25),
        ),
      );
      d['lat'] = pos.latitude;
      d['lng'] = pos.longitude;
      d['city'] = 'GPS location';
      await save();
      await rescheduleReminders();
      return null;
    } catch (_) {
      return 'Location nahi mili. Shehar chun lein.';
    }
  }

  Future<void> rescheduleReminders() async {
    try {
      final la = lat;
      final ln = lng;
      if (!remind || la == null || ln == null) {
        await Notifier.cancelAll();
        return;
      }
      await Notifier.schedule(la, ln);
    } catch (_) {}
  }
}
