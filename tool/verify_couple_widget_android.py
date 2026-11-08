#!/usr/bin/env python3
"""Exercise the production AppWidget on a disposable, offline English emulator.

Install a debug APK and place the real Couple days widget in Launcher first.
This deliberately replaces private widget fixtures; never use a personal AVD.
It does not test OAuth, Dart writes, backend consent, or actual logout/end APIs.
"""
import argparse
import datetime as dt
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

PACKAGE = "com.yunitrish.taiwanbrawl"
PREFS = "shared_prefs/couple_widget_v1.xml"
PROVIDER = PACKAGE + "/.CoupleDaysWidgetProvider"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument("--synthetic-fixtures", action="store_true", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"emulator-\d+", args.serial):
        parser.error("Only a disposable emulator serial is accepted")
    args.evidence_dir.mkdir(parents=True, exist_ok=False)

    def adb(*words, data=None, check=True):
        return subprocess.run(
            ["adb", "-s", args.serial, *words], input=data,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check, timeout=45,
        )

    def shell(command):
        return adb("shell", command).stdout.decode().strip()

    if shell("getprop ro.kernel.qemu") != "1":
        raise RuntimeError("Not an emulator")
    if shell("settings get global airplane_mode_on") != "1" or shell("settings get global wifi_on") != "0":
        raise RuntimeError("Enable airplane mode and disable Wi-Fi before running")
    shell(f"run-as {PACKAGE} id")  # Fails for non-debuggable APKs.
    widgets = shell("dumpsys appwidget")
    instances = widgets.split("Widgets:", 1)[-1].split("Hosts:", 1)[0]
    if PACKAGE + ".CoupleDaysWidgetProvider" not in instances:
        raise RuntimeError("Place the production widget in Launcher first")
    initial_ui = shell("dumpsys activity activities")
    if not any("launcher" in line.lower() for line in initial_ui.splitlines() if "topResumedActivity=" in line):
        raise RuntimeError("Leave the emulator on its Launcher home screen")

    original = adb("exec-out", "run-as", PACKAGE, "cat", PREFS, check=False)
    if original.returncode != 0:
        raise RuntimeError("Widget preferences must exist before running")
    original_scale = shell("settings get system font_scale")
    night = shell("cmd uimode night")
    original_night = re.search(r"Night mode: (\w+)", night)
    if original_night is None or original_night[1] not in {"yes", "no", "auto", "custom"}:
        raise RuntimeError("Cannot determine the original night mode")
    report = {
        "level": "android-emulator-production-provider-with-synthetic-private-snapshots",
        "device": {"sdk": shell("getprop ro.build.version.sdk"), "timezone": shell("getprop persist.sys.timezone")},
        "cases": [],
        "restored": False,
        "notTested": ["OAuth", "backend consent/end/logout", "Dart beginSession/replace channel",
                      "physical device battery", "reboot", "automatic midnight alarm timing", "iOS"],
    }

    def refresh():
        shell(f"run-as {PACKAGE} am broadcast --user 0 -n {PROVIDER} -a {PACKAGE}.COUPLE_WIDGET_DAY")

    def write_preferences(contents):
        shell(f"am kill {PACKAGE}")
        adb("shell", f"run-as {PACKAGE} sh -c 'cat > {PREFS}'", data=contents)
        refresh()

    def seed(status):
        record = dict(schemaVersion=1, accountScope=None if status == "signedOut" else "a" * 64,
                      sessionGeneration=10, requestSequence=1,
                      relationshipId="synthetic-device-check" if status == "active" else None,
                      relationshipVersion=1 if status == "active" else None,
                      startedOn="2026-10-06" if status == "active" else None,
                      status=status, lastSyncedAt="2026-10-06T00:00:00Z" if status == "active" else None)
        payload = html.escape(json.dumps(record))
        write_preferences(f'<?xml version="1.0" encoding="utf-8"?><map><string name="snapshot">{payload}</string></map>'.encode())

    def capture(name, expected):
        # Remove old dump first; a failed dump must never reuse a previous screen.
        for attempt in range(4):
            shell("rm -f /sdcard/couple-widget-check.xml")
            shell("uiautomator dump /sdcard/couple-widget-check.xml")
            raw = adb("exec-out", "cat", "/sdcard/couple-widget-check.xml").stdout
            nodes = [n for n in ET.fromstring(raw).iter("node") if n.get("resource-id") == PACKAGE + ":id/couple_widget_text"]
            if nodes and all(n.get("text") == expected for n in nodes):
                break
            if attempt == 3:
                raise AssertionError(f"{name}: expected {expected!r}; observed {[n.get('text') for n in nodes]}")
            time.sleep(0.5)
        png = adb("exec-out", "screencap", "-p").stdout
        (args.evidence_dir / f"{name}.xml").write_bytes(raw)
        (args.evidence_dir / f"{name}.png").write_bytes(png)
        report["cases"].append(dict(name=name, expected=expected, instances=len(nodes),
                                    bounds=[n.get("bounds") for n in nodes], pngSha256=hashlib.sha256(png).hexdigest()))

    try:
        shell("cmd uimode night no")
        shell("settings put system font_scale 1.0")
        seed("active")
        today = dt.date.fromisoformat(shell("date +%F"))
        days = max(1, (today - dt.date(2026, 10, 6)).days + 1)
        capture("active-light", f"Day {days}")
        shell("cmd uimode night yes")
        shell("settings put system font_scale 2.0")
        refresh()
        capture("active-dark-large", f"Day {days}")
        seed("unbound")
        capture("unbound-dark-large", "No partner linked")
        seed("signedOut")
        capture("signed-out-dark-large", "Please sign in")
        report["passed"] = True
    finally:
        try:
            shell(f"settings put system font_scale {original_scale}" if original_scale != "null" else "settings delete system font_scale")
            shell(f"cmd uimode night {original_night[1]}")
            write_preferences(original.stdout)
            report["restored"] = True
        finally:
            (args.evidence_dir / "result.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
