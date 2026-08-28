#!/usr/bin/env python3
import re, sys, json
from pathlib import Path

project = Path(sys.argv[1]).resolve()
module = sys.argv[2] if len(sys.argv) > 2 else ""
mode = (sys.argv[3] if len(sys.argv) > 3 else "NEW").upper()
out = Path(sys.argv[4]).resolve()

module_dir = project if not module else project.joinpath(*module.split(":"))
candidates = [module_dir / "build.gradle.kts", module_dir / "build.gradle"]
build_file = next((p for p in candidates if p.exists()), None)
if not build_file:
    print("VERSION ERROR: app build.gradle(.kts) not found")
    sys.exit(1)

text = build_file.read_text(encoding="utf-8")
orig = text

vc_patterns = [
    r'(\bversionCode\s*=\s*)(\d+)',
    r'(\bversionCode\s+)(\d+)',
]
vn_patterns = [
    r'(\bversionName\s*=\s*["\'])([^"\']+)(["\'])',
    r'(\bversionName\s+["\'])([^"\']+)(["\'])',
]

version_code = None
for pat in vc_patterns:
    m = re.search(pat, text)
    if m:
        version_code = int(m.group(2))
        vc_pat = pat
        break

version_name = None
for pat in vn_patterns:
    m = re.search(pat, text)
    if m:
        version_name = m.group(2)
        vn_pat = pat
        break

result = {
    "file": str(build_file),
    "mode": mode,
    "old_versionCode": version_code,
    "old_versionName": version_name,
    "changed": False,
}

if mode == "UPDATE":
    if version_code is None:
        print("VERSION ERROR: UPDATE mode requires detectable numeric versionCode")
        sys.exit(1)

    new_code = version_code + 1
    text = re.sub(vc_pat, lambda m: m.group(1) + str(new_code), text, count=1)
    result["new_versionCode"] = new_code

    if version_name:
        parts = version_name.split(".")
        if all(p.isdigit() for p in parts) and len(parts) >= 2:
            nums = list(map(int, parts))
            nums[-1] += 1
            new_name = ".".join(map(str, nums))
        else:
            new_name = version_name + ".1"
        text = re.sub(vn_pat, lambda m: m.group(1) + new_name + m.group(3), text, count=1)
        result["new_versionName"] = new_name
    else:
        result["new_versionName"] = None

    if text != orig:
        build_file.write_text(text, encoding="utf-8")
        result["changed"] = True
else:
    result["new_versionCode"] = version_code
    result["new_versionName"] = version_name

out.write_text(json.dumps(result, indent=2), encoding="utf-8")
print("VERSION")
print("=======")
print(f"Build file: {build_file}")
print(f"Mode: {mode}")
print(f"Old versionCode: {version_code}")
print(f"New versionCode: {result.get('new_versionCode')}")
print(f"Old versionName: {version_name}")
print(f"New versionName: {result.get('new_versionName')}")
print(f"Changed: {result['changed']}")
