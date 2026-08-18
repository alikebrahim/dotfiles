#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / ".config/quickshell/scripts/discover-telemetry-paths.py"
SPEC = importlib.util.spec_from_file_location("telemetry_discovery", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8")


def channel(root: Path, index: int, chip: str, stem: str, label: str | None) -> Path:
    hwmon = root / "class/hwmon" / f"hwmon{index}"
    write(hwmon / "name", chip)
    if label is not None:
        write(hwmon / f"{stem}_label", label)
    write(hwmon / f"{stem}_input", "42000")
    return hwmon


class DiscoveryTest(unittest.TestCase):
    def test_selects_semantic_channels_without_assuming_hwmon_numbers(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = channel(root, 41, "coretemp", "temp1", "Package id 0")
            write(package / "temp1_max", "100000")
            write(package / "temp1_crit", "105000")

            system76 = channel(root, 7, "system76_acpi", "temp1", "CPU temp")
            write(system76 / "temp2_label", "GPU temp")
            write(system76 / "temp2_input", "47000")
            write(system76 / "fan1_label", "CPU fan")
            write(system76 / "fan1_input", "3400")
            write(system76 / "fan2_label", "GPU fan")
            write(system76 / "fan2_input", "3300")

            channel(root, 3, "nvme", "temp1", "Composite")
            channel(root, 29, "nvme", "temp1", "Composite")
            channel(root, 5, "spd5118", "temp1", None)
            channel(root, 8, "iwlwifi_1", "temp1", None)

            for policy in (10, 2, 0):
                write(root / f"devices/system/cpu/cpufreq/policy{policy}/scaling_cur_freq", "1800000")

            write(root / "class/power_supply/AC/type", "Mains")
            write(root / "class/power_supply/AC/online", "1")
            write(root / "class/power_supply/BAT0/type", "Battery")
            write(root / "class/power_supply/BAT0/scope", "System")
            write(root / "class/power_supply/BAT0/present", "1")
            write(root / "class/power_supply/BAT0/capacity", "78")
            write(root / "class/power_supply/BAT0/status", "Not charging")
            write(root / "class/power_supply/hidpp_battery_0/type", "Battery")
            write(root / "class/power_supply/hidpp_battery_0/capacity", "29")

            payload = MODULE.discover(root)
            sensors = payload["sensors"]

            self.assertEqual(payload["schemaVersion"], 1)
            self.assertEqual(sensors["cpuPackage"]["chip"], "coretemp")
            self.assertEqual(sensors["cpuPackage"]["label"], "Package id 0")
            self.assertTrue(sensors["cpuPackage"]["input"].endswith("hwmon41/temp1_input"))
            self.assertTrue(sensors["cpuPackage"]["crit"].endswith("hwmon41/temp1_crit"))
            self.assertEqual(sensors["cpuFan"]["label"], "CPU fan")
            self.assertEqual(sensors["gpuFan"]["label"], "GPU fan")
            self.assertEqual(len(sensors["nvmeComposite"]), 2)
            self.assertEqual(len(sensors["dimmTemperature"]), 1)
            self.assertNotIn("iwlwifi_1", [entry["chip"] for entry in sensors["dimmTemperature"]])
            self.assertEqual(
                [Path(path).parent.name for path in payload["cpufreq"]],
                ["policy0", "policy2", "policy10"],
            )
            self.assertTrue(payload["power"]["battery"]["capacity"].endswith("BAT0/capacity"))
            self.assertTrue(payload["power"]["mains"]["online"].endswith("AC/online"))
            self.assertNotIn("hidpp", str(payload["power"]))
            self.assertTrue(all(payload["availability"].values()))

    def test_missing_optional_channels_are_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            payload = MODULE.discover(Path(temporary))
            self.assertIsNone(payload["sensors"]["cpuPackage"])
            self.assertEqual(payload["sensors"]["nvmeComposite"], [])
            self.assertFalse(payload["availability"]["gpuFan"])
            self.assertFalse(payload["availability"]["cpufreq"])
            self.assertIsNone(payload["power"]["battery"])
            self.assertIsNone(payload["power"]["mains"])


if __name__ == "__main__":
    unittest.main()
