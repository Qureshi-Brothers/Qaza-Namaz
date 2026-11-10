"""GitHub Actions mein `flutter create` ke baad Android files ko patch karta hai:
- notifications ke liye core library desugaring
- permissions (notification, location, boot, alarm, internet)
- notification receivers
- app ka naam "Qaza Tracker"
"""
import pathlib
import re

app = pathlib.Path("android/app")

# ---------- gradle ----------
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"
if kts.exists():
    s = kts.read_text()
    if "isCoreLibraryDesugaringEnabled" not in s:
        s = s.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")\n}\n'
        kts.write_text(s)
elif groovy.exists():
    s = groovy.read_text()
    if "coreLibraryDesugaringEnabled" not in s:
        s = s.replace(
            "compileOptions {",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            1,
        )
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n"
        groovy.write_text(s)
else:
    raise SystemExit("build.gradle nahi mili")

# ---------- manifest ----------
m = app / "src/main/AndroidManifest.xml"
t = m.read_text()

perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
"""

receivers = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

if "POST_NOTIFICATIONS" not in t:
    t = t.replace("<application", perms + "    <application", 1)
    t = t.replace("</application>", receivers + "    </application>", 1)
t = re.sub(r'android:label="[^"]*"', 'android:label="Qaza Tracker"', t, count=1)
m.write_text(t)
print("Android patch ho gaya")
