#!/usr/bin/env python3
"""Run Quattro's real AwesomeWM + Quickshell geometry test under Xvfb."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "quickshell/tests/xvfb/awesome-wm-smoke.qml"
AWESOME_RC = ROOT / "quickshell/tests/xvfb/awesome-integration-rc.lua"


def run(command: list[str], env: dict[str, str], timeout: float = 10, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=timeout)
    if check and result.returncode != 0:
        raise RuntimeError(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}{result.stderr}")
    return result


def wait_for(action, description: str, timeout: float = 8):
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            value = action()
            if value:
                return value
        except Exception as error:  # expected while X11/IPC is becoming ready
            last_error = error
        time.sleep(0.05)
    detail = f": {last_error}" if last_error else ""
    raise AssertionError(f"timed out waiting for {description}{detail}")


def parse_lua_string(output: str) -> str:
    match = re.search(r'\bstring\s+"(.*)"\s*$', output.strip(), re.DOTALL)
    if not match:
        raise ValueError(f"unexpected awesome-client output: {output!r}")
    return bytes(match.group(1), "utf-8").decode("unicode_escape")


def awesome_screen_layout(env: dict[str, str]) -> str:
    expression = (
        "local rows={}; for s in screen do local g=s.geometry; local o={}; "
        "for n in pairs(s.outputs or {}) do o[#o+1]=n end; table.sort(o); "
        "rows[#rows+1]=string.format('%d:%d,%d %dx%d outputs=%s',"
        "s.index,g.x,g.y,g.width,g.height,table.concat(o,',')) end; "
        "return table.concat(rows,';')"
    )
    return parse_lua_string(run(["awesome-client", expression], env).stdout)


def randr_monitor_layout(env: dict[str, str]) -> str:
    return run(["xrandr", "--listmonitors"], env).stdout


def parse_awesome_monitors(layout: str) -> set[tuple[str, int, int, int, int]]:
    monitors: set[tuple[str, int, int, int, int]] = set()
    pattern = re.compile(r"\d+:(-?\d+),(-?\d+) (\d+)x(\d+) outputs=([^;]*)")
    for match in pattern.finditer(layout):
        x, y, width, height = (int(match.group(index)) for index in range(1, 5))
        for name in filter(None, match.group(5).split(",")):
            monitors.add((name, x, y, width, height))
    return monitors


def parse_randr_monitors(layout: str) -> set[tuple[str, int, int, int, int]]:
    monitors: set[tuple[str, int, int, int, int]] = set()
    pattern = re.compile(
        r"^\s*\d+:\s+\S+\s+(\d+)(?:/\d+)?x(\d+)(?:/\d+)?"
        r"\+(-?\d+)\+(-?\d+)\s+(\S+)",
        re.MULTILINE,
    )
    for match in pattern.finditer(layout):
        width, height, x, y = (int(match.group(index)) for index in range(1, 5))
        monitors.add((match.group(5), x, y, width, height))
    return monitors


def attest_endpoint(env: dict[str, str], event_log_path: Path) -> str:
    nonce = env["WMTEST_NONCE"]

    def nonce_matches() -> bool:
        result = run(["awesome-client", "return WMTEST_NONCE"], env, check=False)
        if result.returncode != 0:
            return False
        try:
            return parse_lua_string(result.stdout) == nonce
        except ValueError:
            return False

    wait_for(nonce_matches, "private AwesomeWM nonce")
    wait_for(
        lambda: event_log_path.exists() and "config-loaded" in event_log_path.read_text(errors="replace"),
        "test rc startup marker",
    )

    awesome_layout = awesome_screen_layout(env)
    randr_layout = randr_monitor_layout(env)
    awesome_monitors = parse_awesome_monitors(awesome_layout)
    randr_monitors = parse_randr_monitors(randr_layout)
    if not awesome_monitors or awesome_monitors != randr_monitors:
        raise AssertionError(
            "AwesomeWM endpoint topology does not match Xvfb RandR: "
            f"awesome={sorted(awesome_monitors)!r} randr={sorted(randr_monitors)!r}"
        )
    if any(re.match(r"^(?:eDP|HDMI|DP)-", name) for name, *_ in awesome_monitors):
        raise AssertionError(f"live output name reached isolated harness: {awesome_layout}")
    return awesome_layout


def snapshot(env: dict[str, str]) -> list[dict[str, object]]:
    expression = r'''return (function()
      local rows = {}
      for _, c in ipairs(client.get()) do
        local g = c:geometry()
        rows[#rows + 1] = table.concat({
          tostring(c.window), tostring(c.name or ""), tostring(c.class or ""),
          tostring(c.instance or ""), tostring(c.type or ""),
          tostring(g.x), tostring(g.y), tostring(g.width), tostring(g.height),
          tostring(c.border_width or 0), tostring(c.sticky == true),
          tostring(c.skip_taskbar == true), tostring(c == client.focus)
          , tostring(c.screen and c.screen.index or -1)
          , tostring(c.screen and c.screen.geometry.x or -1)
          , tostring(c.screen and c.screen.geometry.width or -1)
        }, "|")
      end
      return table.concat(rows, ";")
    end)()'''
    output = run(["awesome-client", expression], env).stdout
    encoded = parse_lua_string(output)
    clients: list[dict[str, object]] = []
    for row in filter(None, encoded.split(";")):
        fields = row.split("|")
        if len(fields) != 16:
            raise ValueError(f"unexpected client row: {row!r}")
        clients.append({
            "window": int(fields[0]), "name": fields[1], "class": fields[2],
            "instance": fields[3], "type": fields[4],
            "x": int(fields[5]), "y": int(fields[6]), "width": int(fields[7]),
            "height": int(fields[8]), "border": int(fields[9]),
            "sticky": fields[10] == "true", "skip_taskbar": fields[11] == "true",
            "focused": fields[12] == "true",
            "screen_index": int(fields[13]), "screen_x": int(fields[14]),
            "screen_width": int(fields[15]),
        })
    return clients


def ipc(env: dict[str, str], function: str) -> str:
    result = run(["quickshell", "--path", str(FIXTURE), "ipc", "call", "wmtest", function], env)
    return result.stdout.strip()


def classify(clients: list[dict[str, object]]):
    bars = [client for client in clients if client["height"] == 26]
    panels = [client for client in clients if client["width"] == 380 and client["height"] > 26]
    return bars, panels


def assert_dock(client: dict[str, object], description: str) -> None:
    assert client["type"] == "dock", f"{description} type: {client}"
    assert client["border"] == 0, f"{description} border: {client}"
    assert client["sticky"], f"{description} sticky: {client}"
    assert client["skip_taskbar"], f"{description} skip_taskbar: {client}"


def run_inside() -> None:
    if not os.environ.get("WMTEST_NONCE"):
        raise RuntimeError("WMTEST_NONCE is required; run without --inside-xvfb")
    with tempfile.TemporaryDirectory(prefix="quattro-awesome-xvfb.") as temp:
        runtime = Path(temp) / "runtime"
        runtime.mkdir(mode=0o700)
        env = os.environ.copy()
        env.update({
            "XDG_RUNTIME_DIR": str(runtime),
            "QUATTRO_REPO_ROOT": str(ROOT),
            "RESOURCE_NAME": "quattro-quickshell",
            "QML_IMPORT_PATH": str(ROOT / "quickshell/.config/quickshell"),
            "QML2_IMPORT_PATH": str(ROOT / "quickshell/.config/quickshell"),
        })
        awesome_log_path = Path(temp) / "awesome.log"
        quickshell_log_path = Path(temp) / "quickshell.log"
        event_log_path = Path(temp) / "wmtest-events.log"
        env["WMTEST_EVENT_LOG"] = str(event_log_path)
        pre_quickshell_screens = "<endpoint not attested>"
        with awesome_log_path.open("w") as awesome_log, quickshell_log_path.open("w") as quickshell_log:
            awesome = subprocess.Popen(["awesome", "-c", str(AWESOME_RC)], env=env, text=True,
                                       stdout=awesome_log, stderr=subprocess.STDOUT)
            quickshell = None
            try:
                pre_quickshell_screens = attest_endpoint(env, event_log_path)
                quickshell = subprocess.Popen(["quickshell", "--no-color", "--path", str(FIXTURE)], env=env,
                                              text=True, stdout=quickshell_log, stderr=subprocess.STDOUT)
                wait_for(lambda: "ready" in ipc(env, "status"), "Quickshell IPC")
                wait_for(
                    lambda: event_log_path.exists() and "manage-enter" in event_log_path.read_text(errors="replace"),
                    "fixture client managed by test rc",
                )
                wait_for(lambda: len(snapshot(env)) >= 1, "initial Quickshell client")
                prepared = parse_lua_string(run(["awesome-client", r'''return (function()
                  local count = 0
                  for _, c in ipairs(client.get()) do
                    if c.name == "quickshell-shell" and c.type == "dock" then
                      c.border_width = 0
                      c.floating = true
                      c.sticky = true
                      c.skip_taskbar = true
                      count = count + 1
                    end
                  end
                  return "prepared:" .. tostring(count)
                end)()'''], env).stdout)
                if prepared != "prepared:1":
                    raise AssertionError(f"refused broad fixture mutation: {prepared}")

                def settled_bar():
                    bars, panels = classify(snapshot(env))
                    if len(bars) != 1 or panels:
                        raise AssertionError(f"unexpected clients: bars={bars!r}, panels={panels!r}")
                    candidate = bars[0]
                    geometry = (candidate["x"], candidate["y"], candidate["width"], candidate["height"])
                    if geometry != (0, 0, 1920, 26) or candidate["border"] != 0 or not candidate["skip_taskbar"]:
                        raise AssertionError(f"unsettled bar: {candidate!r}")
                    return candidate

                bar = wait_for(settled_bar, "one settled geometry-neutral bar")
                assert_dock(bar, "bar")

                xprop = run(["xprop", "-id", hex(int(bar["window"])), "_NET_WM_STRUT_PARTIAL"], env).stdout
                numbers = [int(value) for value in re.findall(r"\d+", xprop.split("=", 1)[-1])]
                assert len(numbers) == 12 and numbers[2] == 26, f"unexpected bar strut: {xprop.strip()}"

                ipc(env, "openAudio")
                opened = wait_for(lambda: (lambda pair: pair if len(pair[0]) == 1 and len(pair[1]) == 1 else None)(classify(snapshot(env))),
                                  "bar and controls panel")
                panel = opened[1][0]
                assert (panel["x"], panel["y"], panel["width"]) == (1532, 34, 380), panel
                assert_dock(panel, "controls panel")
                assert panel["focused"], f"controls panel did not receive keyboard focus: {panel}"
                ipc(env, "closeControls")
                wait_for(lambda: len(classify(snapshot(env))[1]) == 0, "closed controls panel")

                for cycle in range(1, 4):
                    ipc(env, "hideBar")
                    wait_for(lambda: len(classify(snapshot(env))[0]) == 0, f"hidden bar cycle {cycle}")
                    ipc(env, "showBar")
                    remapped = wait_for(lambda: (lambda bars: bars[0] if len(bars) == 1 else None)(classify(snapshot(env))[0]),
                                        f"remapped bar cycle {cycle}")
                    assert (remapped["x"], remapped["y"], remapped["width"], remapped["height"]) == (0, 0, 1920, 26), remapped
                    assert_dock(remapped, f"remapped bar cycle {cycle}")

                print("ok - AwesomeWM preserves bar/popup geometry, focus, strut, and remapping")
            except Exception:
                awesome_log.flush()
                quickshell_log.flush()
                screen_layout = run(["awesome-client", "return WMTEST_NONCE"], env, check=False)
                randr_layout = run(["xrandr", "--listmonitors"], env, check=False)
                print("--- awesome screens ---", file=sys.stderr)
                print("before Quickshell: " + pre_quickshell_screens, file=sys.stderr)
                print(screen_layout.stdout or screen_layout.stderr, file=sys.stderr)
                print("--- RandR monitors ---", file=sys.stderr)
                print(randr_layout.stdout or randr_layout.stderr, file=sys.stderr)
                print("--- awesome.log ---", file=sys.stderr)
                print(awesome_log_path.read_text(errors="replace")[-8000:], file=sys.stderr)
                print("--- wmtest-events.log ---", file=sys.stderr)
                print(event_log_path.read_text(errors="replace")[-8000:] if event_log_path.exists() else "<missing>", file=sys.stderr)
                print("--- quickshell.log ---", file=sys.stderr)
                print(quickshell_log_path.read_text(errors="replace")[-8000:], file=sys.stderr)
                raise
            finally:
                if quickshell is not None and quickshell.poll() is None:
                    try:
                        ipc(env, "quit")
                    except Exception:
                        quickshell.terminate()
                    try:
                        quickshell.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        quickshell.kill()
                if awesome.poll() is None:
                    awesome.terminate()
                    try:
                        awesome.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        awesome.kill()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inside-xvfb", action="store_true")
    args = parser.parse_args()
    if args.inside_xvfb:
        run_inside()
        return
    env = os.environ.copy()
    env["WMTEST_NONCE"] = secrets.token_hex(16)
    command = ["dbus-run-session", "--", "xvfb-run", "-a", "-s",
               "-screen 0 1920x1080x24 -extension XINERAMA -nolisten tcp",
               sys.executable, str(Path(__file__).resolve()), "--inside-xvfb"]
    raise SystemExit(subprocess.run(command, env=env).returncode)


if __name__ == "__main__":
    main()
