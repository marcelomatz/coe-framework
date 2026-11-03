#!/usr/bin/env python3
"""Generate the native vehicle seed from the pinned DurtyFree v3717 dump."""

import argparse
import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "coe_vehicle_catalog" / "data" / "native_vehicles_v3717.json"
OUTPUT_PATH = ROOT / "coe_vehicle_catalog" / "data" / "native_vehicles.lua"
SOURCE_COMMIT = "b8f9dfaee5139fe372f264df4030506d1450fd8a"
SOURCE_URL = (
    "https://raw.githubusercontent.com/DurtyFree/gta-v-data-dumps/"
    f"{SOURCE_COMMIT}/vehicles.json"
)
SOURCE_SHA256 = "cbb3912a3fc3f97c452d5d51f06a78049151e91fe8597541a6f62ae4ea552911"

CLASS_BY_ID = {
    0: ("COMPACT", "compacts"),
    1: ("SEDAN", "sedans"),
    2: ("SUV", "suvs"),
    3: ("COUPE", "coupes"),
    4: ("MUSCLE", "muscle"),
    5: ("SPORT_CLASSIC", "sports_classics"),
    6: ("SPORT", "sports"),
    7: ("SUPER", "super"),
    8: ("MOTORCYCLE", "motorcycles"),
    9: ("OFF_ROAD", "offroad"),
    10: ("INDUSTRIAL", "industrial"),
    11: ("UTILITY", "utility"),
    12: ("VAN", "vans"),
    13: ("CYCLE", "cycles"),
    14: ("BOAT", "boats"),
    15: ("HELICOPTER", "helicopters"),
    16: ("PLANE", "planes"),
    17: ("SERVICE", "service"),
    18: ("EMERGENCY", "emergency"),
    19: ("MILITARY", "military"),
    20: ("COMMERCIAL", "commercial"),
    21: ("RAIL", "trains"),
    22: ("OPEN_WHEEL", "open_wheel"),
}
TYPE_MAP = {
    "CAR": "automobile",
    "AMPHIBIOUS_AUTOMOBILE": "automobile",
    "BIKE": "bike",
    "QUADBIKE": "bike",
    "BICYCLE": "bike",
    "AMPHIBIOUS_QUADBIKE": "bike",
    "BOAT": "boat",
    "HELI": "heli",
    "PLANE": "plane",
    "BLIMP": "plane",
    "SUBMARINE": "submarine",
    "SUBMARINECAR": "submarine",
    "TRAILER": "trailer",
    "TRAIN": "train",
}
MODEL_PATTERN = re.compile(r"^[A-Za-z0-9_]{1,48}$")


def normalize_model(raw):
    model = raw.get("Name")
    class_id = raw.get("ClassId")
    if not isinstance(model, str) or not MODEL_PATTERN.fullmatch(model):
        raise ValueError(f"invalid model name: {model!r}")
    if isinstance(class_id, bool) or not isinstance(class_id, int) or class_id not in CLASS_BY_ID:
        raise ValueError(f"invalid native class id for {model}")
    source_class, class_name = CLASS_BY_ID[class_id]
    if raw.get("Class") != source_class:
        raise ValueError(f"class/class id mismatch for {model}")
    source_type = raw.get("Type")
    if source_type not in TYPE_MAP:
        raise ValueError(f"unsupported vehicle type {source_type!r} for {model}")
    dlc = raw.get("DlcName")
    if not isinstance(dlc, str) or not dlc:
        raise ValueError(f"missing DLC metadata for {model}")
    display = raw.get("DisplayName") or {}
    brand = (raw.get("ManufacturerDisplayName") or {}).get("English") or None
    seats = raw.get("Seats")
    if isinstance(seats, bool) or (seats is not None and not isinstance(seats, int)):
        raise ValueError(f"invalid seat count for {model}")
    return {
        "model": model.lower(),
        "name": display.get("English") or model,
        "brand": brand,
        "class": class_name,
        "type": TYPE_MAP[source_type],
        "seats": seats,
        "classId": class_id,
        "dlc": dlc,
        "sourceType": source_type,
    }


def normalize_dump(raw_models):
    models = [normalize_model(item) for item in raw_models]
    seen = set()
    for model in models:
        if model["model"] in seen:
            raise ValueError(f"duplicate model: {model['model']}")
        seen.add(model["model"])
    return sorted(models, key=lambda item: item["model"])


def refresh_source():
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "coe-framework-vehicle-catalog"})
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = response.read()
    digest = hashlib.sha256(payload).hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError(f"source hash mismatch: expected {SOURCE_SHA256}, got {digest}")
    raw_models = json.loads(payload)
    models = normalize_dump(raw_models)
    if len(models) != 921:
        raise ValueError(f"expected pinned v3717 inventory of 921, got {len(models)}")
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    SOURCE_PATH.write_text(
        json.dumps(
            {
                "source": SOURCE_URL,
                "commit": SOURCE_COMMIT,
                "sha256": digest,
                "models": models,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def load_source():
    data = json.loads(SOURCE_PATH.read_text(encoding="utf-8"))
    if data.get("commit") != SOURCE_COMMIT or data.get("sha256") != SOURCE_SHA256:
        raise ValueError("versioned source provenance does not match the pinned dump")
    models = data.get("models")
    if not isinstance(models, list) or len(models) != 921:
        raise ValueError("versioned source must contain exactly 921 v3717 models")
    normalized = []
    seen = set()
    for model in models:
        if not isinstance(model, dict):
            raise ValueError("invalid normalized source row")
        name = model.get("model")
        if not isinstance(name, str) or not MODEL_PATTERN.fullmatch(name) or name in seen:
            raise ValueError(f"invalid or duplicate normalized model: {name!r}")
        seen.add(name)
        if model.get("classId") not in CLASS_BY_ID or CLASS_BY_ID[model["classId"]][1] != model.get("class"):
            raise ValueError(f"class/class id mismatch for {name}")
        if model.get("type") not in set(TYPE_MAP.values()):
            raise ValueError(f"invalid normalized type for {name}")
        if not isinstance(model.get("dlc"), str) or not model["dlc"]:
            raise ValueError(f"missing DLC metadata for {name}")
        normalized.append(model)
    return normalized


def lua_string(value):
    return json.dumps(value, ensure_ascii=False)


def render_lua(models):
    rows = []
    for vehicle in models:
        brand = lua_string(vehicle["brand"]) if vehicle["brand"] else "nil"
        seats = str(vehicle["seats"]) if vehicle["seats"] is not None else "nil"
        rows.append(
            "\t{ %s, %s, %s, %s, %s, %s, %d, %s }"
            % (
                lua_string(vehicle["model"]),
                lua_string(vehicle["name"]),
                brand,
                lua_string(vehicle["class"]),
                lua_string(vehicle["type"]),
                seats,
                vehicle["classId"],
                lua_string(vehicle["dlc"]),
            )
        )
    return (
        "-- Generated by tools/generate_native_vehicles.py; do not edit by hand.\n"
        f"-- DurtyFree gta-v-data-dumps vehicles.json commit {SOURCE_COMMIT} (v3717.0).\n"
        "CoeNativeVehicles = {\n"
        + ",\n".join(rows)
        + "\n}\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh-source", action="store_true", help="download and verify the pinned upstream dump")
    parser.add_argument("--check", action="store_true", help="fail if generated Lua differs from the checked-in file")
    args = parser.parse_args()
    try:
        if args.refresh_source:
            refresh_source()
        models = load_source()
        generated = render_lua(models)
        if args.check:
            if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_text(encoding="utf-8") != generated:
                print("native_vehicles.lua is stale; run python tools/generate_native_vehicles.py", file=sys.stderr)
                return 1
        else:
            OUTPUT_PATH.write_text(generated, encoding="utf-8")
        print(f"{len(models)} vehicles from pinned v3717 source")
        return 0
    except (OSError, ValueError, urllib.error.URLError, json.JSONDecodeError) as error:
        print(f"vehicle catalog generation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
