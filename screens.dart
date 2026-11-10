import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'calc.dart';
import 'notify.dart';
import 'store.dart';

Future<String?> pickGender(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Aap kaun hain?'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c, 'male'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Mard', style: TextStyle(fontSize: 18)),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c, 'female'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aurat', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    ),
  );
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ================= Root =================
class Root extends StatelessWidget {
  final AppState s;
  const Root(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        if (s.gender == null) return WelcomeScreen(s);
        if (!s.setupDone) return SetupScreen(s, pushed: false);
        return HomeScreen(s);
      },
    );
  }
}

// ================= Welcome =================
class WelcomeScreen extends StatelessWidget {
  final AppState s;
  const WelcomeScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.nights_stay, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text(
                'Qaza Tracker',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Qaza namaz aur qaza roze ka hisab, aur har namaz par yaad dehani.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (cloudReady) ...[
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AuthScreen(s, signUp: true)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Naya account banayein'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AuthScreen(s, signUp: false)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Login'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextButton(
                onPressed: () async {
                  final g = await pickGender(context);
                  if (g != null) await s.setGender(g);
                },
                child: const Text('Bina account ke chalayein (sirf phone mein)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= Login / Sign up =================
class AuthScreen extends StatefulWidget {
  final AppState s;
  final bool signUp;
  const AuthScreen(this.s, {super.key, required this.signUp});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  String? gender;
  bool busy = false;
  String? msg;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final e = email.text.trim();
    final p = pass.text;
    if (e.isEmpty || p.length < 6) {
      setState(() => msg = 'Email likhein aur password kam az kam 6 harf ka rakhein.');
      return;
    }
    if (widget.signUp && gender == null) {
      setState(() => msg = 'Mard ya Aurat chunein.');
      return;
    }
    setState(() {
      busy = true;
      msg = null;
    });
    final c = Supabase.instance.client;
    try {
      if (widget.signUp) {
        final r = await c.auth.signUp(email: e, password: p, data: {'gender': gender});
        if (r.session == null) {
          setState(() {
            busy = false;
            msg = 'Account ban gaya. Email mein confirm link aaya hoga, confirm karke Login karein.';
          });
          return;
        }
        await widget.s.afterLogin();
        await widget.s.setGender(gender!);
      } else {
        await c.auth.signInWithPassword(email: e, password: p);
        await widget.s.afterLogin();
        if (widget.s.gender == null) {
          if (!mounted) return;
          final g = await pickGender(context);
          if (g != null) await widget.s.setGender(g);
        }
      }
      if (mounted) Navigator.pop(context);
    } on AuthException catch (ex) {
      setState(() {
        busy = false;
        msg = ex.message;
      });
    } catch (_) {
      setState(() {
        busy = false;
        msg = 'Masla aaya. Internet check karke dobara koshish karein.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.signUp ? 'Naya account' : 'Login')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          ),
          if (widget.signUp) ...[
            const SizedBox(height: 18),
            const Text('Aap kaun hain?', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: const Text('Mard'),
              value: 'male',
              groupValue: gender,
              onChanged: (v) => setState(() => gender = v),
            ),
            RadioListTile<String>(
              title: const Text('Aurat'),
              value: 'female',
              groupValue: gender,
              onChanged: (v) => setState(() => gender = v),
            ),
          ],
          if (msg != null) ...[
            const SizedBox(height: 12),
            Text(msg!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : _go,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.signUp ? 'Account banayein' : 'Login karein'),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Hisab (Setup) =================
class SetupScreen extends StatefulWidget {
  final AppState s;
  final bool pushed;
  const SetupScreen(this.s, {super.key, required this.pushed});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool byAge = true;
  bool includeRoza = true;
  bool computed = false;

  final bulugh = TextEditingController(text: '15');
  final age = TextEditingController();
  final prayed = TextEditingController(text: '0');
  final years = TextEditingController();
  final haiz = TextEditingController(text: '6');
  final children = TextEditingController(text: '0');
  final nifas = TextEditingController(text: '30');

  final Map<String, TextEditingController> res = {
    for (final k in prayerKeys) k: TextEditingController(text: '0'),
  };
  final rozaRes = TextEditingController(text: '0');

  double _d(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
  int _i(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  void _compute() {
    final i = CalcInput();
    i.byAge = byAge;
    i.bulughAge = _d(bulugh);
    i.currentAge = _d(age);
    i.prayedYears = _d(prayed);
    i.qazaYears = _d(years);
    i.female = widget.s.female;
    i.haizDays = _i(haiz);
    i.children = _i(children);
    i.nifasDays = _i(nifas);
    i.includeRoza = includeRoza;
    final r = calculate(i);
    setState(() {
      for (final k in prayerKeys) {
        res[k]!.text = '${r.prayers[k] ?? 0}';
      }
      rozaRes.text = '${r.roza}';
      computed = true;
    });
  }

  Future<void> _save() async {
    final p = <String, int>{};
    for (final k in prayerKeys) {
      final v = _i(res[k]!);
      p[k] = v < 0 ? 0 : v;
    }
    final r = _i(rozaRes);
    await widget.s.applyCounts(p, r < 0 ? 0 : r);
    if (widget.pushed && mounted) Navigator.pop(context);
  }

  Widget _num(TextEditingController c, String label, {bool decimal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [bulugh, age, prayed, years, haiz, children, nifas, rozaRes]) {
      c.dispose();
    }
    for (final c in res.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final female = widget.s.female;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qaza ka hisab'),
        automaticallyImplyLeading: widget.pushed,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Hisab ka tareeqa chunein:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Baligh hone ki umar se'),
                selected: byAge,
                onSelected: (_) => setState(() => byAge = true),
              ),
              ChoiceChip(
                label: const Text('Saalon ke andaze se'),
                selected: !byAge,
                onSelected: (_) => setState(() => byAge = false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (byAge) ...[
            _num(bulugh, 'Baligh hone ki umar (saal)', decimal: true),
            _num(age, 'Aaj ki umar (saal)', decimal: true),
            _num(prayed, 'Kitne saal namaz regular parhi (agar koi)', decimal: true),
          ] else
            _num(years, 'Kitne saal ki qaza hai (andaza)', decimal: true),
          if (female) ...[
            const Text('Aurat ke liye (ye din hisab se minus honge):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _num(haiz, 'Har mahine haiz ke din (apni aadat)'),
            _num(children, 'Bachon ki tadaad (nifas ke liye)'),
            _num(nifas, 'Har bache par nifas ke din'),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Qaza roze ka hisab bhi karein'),
            value: includeRoza,
            onChanged: (v) => setState(() => includeRoza = v ?? true),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _compute,
            child: const Padding(padding: EdgeInsets.all(10), child: Text('Hisab karein')),
          ),
          TextButton(
            onPressed: () => setState(() => computed = true),
            child: const Text('Hisab chhor kar khud ginti likhein'),
          ),
          if (computed) ...[
            const Divider(height: 32),
            const Text('Nateeja (aap badal sakte hain):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final k in prayerKeys) _num(res[k]!, '${prayerNames[k]} ki qaza'),
            _num(rozaRes, 'Qaza roze'),
            const Text(
              'Hisab: 1 saal = 365 din, Ramadan = 30 roze (ehtiyat ke taur par). '
              'Aurat ke roze mein sirf haiz minus hota hai. Nifas wagaira ke masail mufti/aalim se pooch lein.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              child: const Padding(padding: EdgeInsets.all(10), child: Text('Save karein')),
            ),
          ],
        ],
      ),
    );
  }
}

// ================= Home =================
class HomeScreen extends StatefulWidget {
  final AppState s;
  const HomeScreen(this.s, {super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Notifier.askPermission();
      if (widget.s.lat == null) {
        await widget.s.useGps();
      } else {
        await widget.s.rescheduleReminders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final pages = <Widget>[QazaTab(s), AuqatTab(s), SettingsTab(s)];
        return Scaffold(
          appBar: AppBar(title: const Text('Qaza Tracker')),
          body: pages[tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.checklist), label: 'Qaza'),
              NavigationDestination(icon: Icon(Icons.access_time), label: 'Auqat'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Qaza tab ----------
class QazaTab extends StatelessWidget {
  final AppState s;
  const QazaTab(this.s, {super.key});

  String _estimate() {
    final left = s.totalLeft;
    if (left <= 0) return 'Alhamdulillah, saari qaza namaz poori!';
    final rate = s.avgPerDay > 0 ? s.avgPerDay : s.target.toDouble();
    final days = (left / rate).ceil();
    final end = DateTime.now().add(Duration(days: days));
    return 'Is raftaar se takriban $days din (${end.day}/${end.month}/${end.year})';
  }

  Widget _row(BuildContext context, String title, int left, VoidCallback done, VoidCallback undo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('Baqi: $left'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Galti se ghat gayi to ek wapas jama karein',
              onPressed: undo,
              icon: const Icon(Icons.add_circle_outline),
            ),
            FilledButton.tonal(
              onPressed: left > 0 ? done : null,
              child: const Text('Parh li'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = s.prayers;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Baqi qaza namaz'),
                Text('${s.totalLeft}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: s.progress, minHeight: 8),
                const SizedBox(height: 8),
                Text('Ab tak poori: ${s.doneTotal}  (${(s.progress * 100).toStringAsFixed(1)}%)'),
                Text('Aaj parhi: ${s.todayDone} / ${s.target}'),
                const SizedBox(height: 4),
                Text(_estimate(), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Namaz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        for (final k in prayerKeys)
          _row(
            context,
            prayerNames[k] ?? k,
            p[k] ?? 0,
            () => s.changePrayer(k, -1),
            () => s.changePrayer(k, 1),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Roza', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        _row(
          context,
          'Qaza roze',
          s.roza,
          () => s.changeRoza(-1),
          () => s.changeRoza(1),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------- Auqat tab ----------
class AuqatTab extends StatelessWidget {
  final AppState s;
  const AuqatTab(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final la = s.lat;
    final ln = s.lng;
    List<PT> times = [];
    if (la != null && ln != null) {
      try {
        times = prayerTimesFor(la, ln, DateTime.now());
      } catch (_) {}
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  la == null ? 'Location set nahi hai' : 'Location: ${s.city.isEmpty ? "GPS location" : s.city}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    final m = await s.useGps();
                    if (m != null && context.mounted) snack(context, m);
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('GPS se location lein'),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Ya shehar chunein'),
                  value: cities.containsKey(s.city) ? s.city : null,
                  items: [
                    for (final c in cities.keys) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    if (v != null) s.setCity(v);
                  },
                ),
              ],
            ),
          ),
        ),
        if (times.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final t in times)
                  ListTile(
                    dense: true,
                    title: Text(t.name),
                    trailing: Text(
                      fmtTime(t.time),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: t.isPrayer ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            title: const Text('Har namaz par qaza ki yaad dehani'),
            subtitle: const Text('Har namaz ke waqt notification aayega'),
            value: s.remind,
            onChanged: (v) => s.setRemind(v),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Auqat Karachi method aur Hanafi Asr se hisab hote hain (internet ke baghair). '
            'Reminder ke liye notification ki ijazat dein, aur phone ki battery saver is app ko band na kare.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ---------- Settings tab ----------
class SettingsTab extends StatelessWidget {
  final AppState s;
  const SettingsTab(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (!cloudReady)
                  const Text('Online account abhi on nahi. Data sirf is phone mein hai.')
                else if (s.loggedIn) ...[
                  Text('Login: ${s.email ?? ""}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final m = await s.pushCloud();
                          if (context.mounted) snack(context, m ?? 'Online save ho gaya.');
                        },
                        child: const Text('Abhi sync karein'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Logout?'),
                              content: const Text(
                                'Phone se data hat jayega. Online save rahega, dobara login karne par wapas aa jayega.',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nahi')),
                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Logout')),
                              ],
                            ),
                          );
                          if (ok == true) await s.logout();
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text('Abhi data sirf phone mein hai. Account se online save aur doosre phone par bhi mil sakta hai.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AuthScreen(s, signUp: false)),
                    ),
                    child: const Text('Login / Sign up'),
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.calculate),
                title: const Text('Dobara hisab / ginti badlein'),
                subtitle: const Text('Naya hisab karne se progress dobara shuru hogi'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SetupScreen(s, pushed: true)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: Text('Roz ka target: ${s.target} namaz'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => s.setTarget(s.target - 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => s.setTarget(s.target + 1),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text('Aap: ${s.female ? "Aurat" : "Mard"}'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Ye app sirf hisab rakhne mein madad deti hai. Hanafi fiqh ke mutabiq witr shamil hai. '
            'Masail ke liye apne mufti ya aalim se rujoo karein.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
