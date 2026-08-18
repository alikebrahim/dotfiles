#!/usr/bin/env python3
"""Discover read-only telemetry paths by semantic chip and channel labels."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
from typing import Any

SCHEMA_VERSION = 1
MAX_CHANNELS_PER_GROUP = 16
MAX_CPU_POLICIES = 256


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""


def _natural_key(path: Path) -> list[object]:
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", path.name)]


def _channel_record(hwmon: Path, chip: str, input_path: Path) -> dict[str, Any]:
    stem = input_path.name.removesuffix("_input")
    record: dict[str, Any] = {
        "chip": chip,
        "label": _read_text(hwmon / f"{stem}_label"),
        "input": str(input_path.absolute()),
    }
    for suffix in ("max", "crit"):
        candidate = hwmon / f"{stem}_{suffix}"
        if candidate.is_file():
            record[suffix] = str(candidate.absolute())
    return record


def _enumerate_channels(sysfs_root: Path) -> list[dict[str, Any]]:
    channels: list[dict[str, Any]] = []
    hwmon_root = sysfs_root / "class" / "hwmon"
    for hwmon in sorted(hwmon_root.glob("hwmon*"), key=_natural_key):
        chip = _read_text(hwmon / "name")
        if not chip:
            continue
        inputs = list(hwmon.glob("temp*_input")) + list(hwmon.glob("fan*_input"))
        for input_path in sorted(inputs, key=_natural_key):
            channels.append(_channel_record(hwmon, chip, input_path))
    return channels


def _normalized(value: str) -> str:
    return " ".join(value.casefold().split())


def _first(
    channels: list[dict[str, Any]],
    *,
    chip: str,
    label: str | None = None,
) -> dict[str, Any] | None:
    chip_key = chip.casefold()
    label_key = _normalized(label or "")
    for channel in channels:
        if str(channel["chip"]).casefold() != chip_key:
            continue
        if label is not None and _normalized(str(channel.get("label", ""))) != label_key:
            continue
        return channel
    return None


def _all(
    channels: list[dict[str, Any]],
    *,
    chip: str,
    label: str | None = None,
) -> list[dict[str, Any]]:
    chip_key = chip.casefold()
    label_key = _normalized(label or "")
    selected: list[dict[str, Any]] = []
    for channel in channels:
        if str(channel["chip"]).casefold() != chip_key:
            continue
        if label is not None and _normalized(str(channel.get("label", ""))) != label_key:
            continue
        selected.append(channel)
        if len(selected) >= MAX_CHANNELS_PER_GROUP:
            break
    return selected


def _power_record(power_supply: Path, fields: tuple[str, ...]) -> dict[str, str]:
    record: dict[str, str] = {}
    for field in fields:
        candidate = power_supply / field
        if candidate.is_file():
            record[field] = str(candidate.absolute())
    return record


def _discover_power(sysfs_root: Path) -> dict[str, Any]:
    supplies = sysfs_root / "class" / "power_supply"
    battery: dict[str, str] | None = None
    mains: dict[str, str] | None = None

    for supply in sorted(supplies.glob("*"), key=_natural_key):
        supply_type = _read_text(supply / "type").casefold()
        if supply_type == "mains" and mains is None:
            candidate = _power_record(supply, ("online",))
            if candidate:
                mains = candidate
            continue
        if supply_type != "battery" or battery is not None:
            continue

        scope = _read_text(supply / "scope").casefold()
        internal_name = re.fullmatch(r"BAT\d+", supply.name, re.IGNORECASE) is not None
        if scope != "system" and not internal_name:
            continue
        candidate = _power_record(supply, ("present", "capacity", "status"))
        if candidate:
            battery = candidate

    return {"battery": battery, "mains": mains}


def discover(sysfs_root: Path) -> dict[str, Any]:
    root = sysfs_root.absolute()
    channels = _enumerate_channels(root)
    cpufreq_root = root / "devices" / "system" / "cpu" / "cpufreq"
    policies = sorted(cpufreq_root.glob("policy*/scaling_cur_freq"), key=lambda path: _natural_key(path.parent))
    cpufreq = [str(path.absolute()) for path in policies[:MAX_CPU_POLICIES] if path.is_file()]

    sensors: dict[str, Any] = {
        "cpuPackage": _first(channels, chip="coretemp", label="Package id 0"),
        "cpuFallback": _first(channels, chip="system76_acpi", label="CPU temp"),
        "gpuTemperature": _first(channels, chip="system76_acpi", label="GPU temp"),
        "cpuFan": _first(channels, chip="system76_acpi", label="CPU fan"),
        "gpuFan": _first(channels, chip="system76_acpi", label="GPU fan"),
        "nvmeComposite": _all(channels, chip="nvme", label="Composite"),
        "dimmTemperature": _all(channels, chip="spd5118"),
    }
    availability = {
        key: bool(value)
        for key, value in sensors.items()
    }
    availability["cpufreq"] = bool(cpufreq)
    power = _discover_power(root)
    availability["battery"] = bool(power["battery"])
    availability["mains"] = bool(power["mains"])

    return {
        "schemaVersion": SCHEMA_VERSION,
        "sysfsRoot": str(root),
        "sensors": sensors,
        "cpufreq": cpufreq,
        "power": power,
        "availability": availability,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sysfs-root", type=Path, default=Path("/sys"))
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    payload = discover(args.sysfs_root)
    print(json.dumps(payload, indent=2 if args.pretty else None, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
