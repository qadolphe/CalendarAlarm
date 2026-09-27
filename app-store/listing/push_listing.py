#!/usr/bin/env python3
"""Pushes listing.json (copy and screenshots) to the editable App Store version.

Usage: ASC_KEY_ID=... ASC_ISSUER_ID=... ./push_listing.py [--dry-run]
The .p8 key is read from ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8.
"""
import base64, hashlib, json, os, pathlib, subprocess, sys, time, urllib.error, urllib.request

APP_ID = "6766083287"
DISPLAY_TYPE = "APP_IPHONE_67"  # 6.7" and 6.9" iPhones (1320x2868)
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
HERE = pathlib.Path(__file__).parent
DRY_RUN = "--dry-run" in sys.argv


def token():
    key_id, issuer = os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"]
    key = pathlib.Path.home() / f".appstoreconnect/private_keys/AuthKey_{key_id}.p8"
    b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=")
    now = int(time.time())
    msg = b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode()) + b"." + b64(
        json.dumps({"iss": issuer, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key], input=msg, capture_output=True, check=True).stdout
    # Convert the DER-encoded ECDSA signature into the raw r||s form JWT expects.
    r_len = der[3]; r = der[4:4 + r_len]; s = der[6 + r_len:]
    return (msg + b"." + b64(r.lstrip(b"\0").rjust(32, b"\0") + s.lstrip(b"\0").rjust(32, b"\0"))).decode()


def api(method, path, body=None):
    if DRY_RUN and method != "GET":
        print(f"  [dry-run] {method} {path}")
        return {"data": {"id": "dry-run", "attributes": {"uploadOperations": []}}}
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        raw = urllib.request.urlopen(req).read()
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path} failed: {error.code} {error.read().decode()[:400]}")
    return json.loads(raw) if raw else {}


def upsert(kind, existing, parent_rel, parent_id, attributes):
    """PATCHes an existing localization or creates one under its parent."""
    if existing:
        api("PATCH", f"/v1/{kind}/{existing['id']}",
            {"data": {"type": kind, "id": existing["id"], "attributes": attributes}})
        return existing["id"]
    created = api("POST", f"/v1/{kind}", {"data": {
        "type": kind, "attributes": attributes,
        "relationships": {parent_rel: {"data": {"type": parent_rel + "s", "id": parent_id}}}}})
    return created["data"]["id"]


def replace_screenshots(localization_id, files):
    if DRY_RUN and localization_id == "dry-run":
        print(f"  [dry-run] upload {len(files)} screenshots")
        return
    sets = api("GET", f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")["data"]
    shot_set = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE), None)
    if shot_set:
        for shot in api("GET", f"/v1/appScreenshotSets/{shot_set['id']}/appScreenshots")["data"]:
            api("DELETE", f"/v1/appScreenshots/{shot['id']}")
        set_id = shot_set["id"]
    else:
        set_id = api("POST", "/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
            "relationships": {"appStoreVersionLocalization": {"data": {
                "type": "appStoreVersionLocalizations", "id": localization_id}}}}})["data"]["id"]

    for path in files:
        data = path.read_bytes()
        shot = api("POST", "/v1/appScreenshots", {"data": {
            "type": "appScreenshots", "attributes": {"fileName": path.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
            urllib.request.urlopen(urllib.request.Request(op["url"], data=chunk, method=op["method"], headers=headers))
        api("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {
            "type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


def main():
    listing = json.loads((HERE / "listing.json").read_text())
    copy = listing["default"]
    screenshots = [(HERE / p).resolve() for p in listing["screenshots"]]

    versions = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions?limit=5")["data"]
    version = next((v for v in versions if v["attributes"]["appStoreState"] in EDITABLE), None)
    infos = api("GET", f"/v1/apps/{APP_ID}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("state") != "READY_FOR_DISTRIBUTION"
                 and i["attributes"].get("appStoreState") != "READY_FOR_SALE"), None)
    if not version or not info:
        sys.exit("No editable version. Create one in App Store Connect, or wait for the version in review.")
    print(f"Updating {version['attributes']['versionString']} ({version['attributes']['appStoreState']})")

    def localizations(path):
        return {l["attributes"]["locale"]: l for l in api("GET", path)["data"]}

    info_locs = localizations(f"/v1/appInfos/{info['id']}/appInfoLocalizations")

    for locale in listing["locales"]:
        print(locale)
        info_attrs = {"name": copy["name"], "subtitle": copy["subtitle"]}
        if locale not in info_locs:
            info_attrs["locale"] = locale
        upsert("appInfoLocalizations", info_locs.get(locale), "appInfo", info["id"], info_attrs)

        # Adding a language creates its version localization too, so read them after.
        version_locs = localizations(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
        version_attrs = {k: copy[k] for k in ("keywords", "promotionalText", "description", "whatsNew")}
        if locale not in version_locs:
            version_attrs["locale"] = locale
        localization_id = upsert("appStoreVersionLocalizations", version_locs.get(locale),
                                 "appStoreVersion", version["id"], version_attrs)
        replace_screenshots(localization_id, screenshots)


if __name__ == "__main__":
    main()
