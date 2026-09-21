# Data model: kind, label, names, belt, icon, original announcement.
# Explicit non-title / qualifier stakes take precedence over champion names.
TITLES = [
    ["WOMEN'S WORLD", "WOMENS WORLD", "worldwhite"],
    ["WORLD HEAVYWEIGHT", "WORLD TITLE", "world"],
    ["WOMEN'S INTERCONTINENTAL", "WOMENS IC", "icwhite"],
    ["INTERCONTINENTAL", "IC TITLE", "ic"],
    ["WOMEN'S UNITED STATES", "WOMENS US", "uswhite"],
    ["UNITED STATES", "US TITLE", "us"],
    ["WOMEN'S TAG TEAM", "WOMENS TAG", "womentag"],
    ["WORLD TAG TEAM", "WORLD TAG", "worldtag"],
    ["WWE TAG TEAM", "WWE TAG", "wwetag"],
    ["NXT WOMEN'S NORTH AMERICAN", "NXT WOMENS NA", "nawhite"],
    ["NXT NORTH AMERICAN", "NXT NA TITLE", "na"],
    ["NXT WOMEN'S", "NXT WOMENS", "nxtwhite"],
    ["NXT TAG TEAM", "NXT TAG TITLE", "nxttag"],
    ["NXT", "NXT TITLE", "nxt"],
    ["WWE WOMEN'S", "WWE WOMENS", "women"],
    ["UNDISPUTED WWE", "WWE TITLE", "wwe"],
    ["WWE CHAMPIONSHIP", "WWE TITLE", "wwe"],
]

# 1v1s that the list writes as names-only, but the bout is the champion's title.
CHAMPIONS = [
    ["LYRA VALKYRIA", "WOMENS IC", "icwhite"],
]

def segment_text(raw):
    # Fonts have no apostrophe, so "WE'LL HEAR FROM X" draws as WELL HEAR.
    s = str(raw).upper().replace("'", "").replace("’", "")
    for prefix in ["WELL HEAR FROM ", "WE LL HEAR FROM ", "WE WILL HEAR FROM ", "FANS WILL HEAR FROM ", "HEAR FROM "]:
        if s.startswith(prefix):
            name = s[len(prefix):].strip(" .")
            for tail in [" ON RAW", " ON SMACKDOWN", " ON NXT", " TONIGHT", " THIS WEEK"]:
                if name.endswith(tail):
                    name = name[:len(name) - len(tail)].strip()
            if name != "" and " VS " not in name:
                return name + " TO SPEAK"
    return s

def normalize_item(raw):
    cleaned = raw.replace(" VS. ", " VS ").replace(" V. ", " VS ")
    label = "SINGLES MATCH"
    belt = ""
    icon = ""
    names = cleaned
    stakes = ""
    if ": " in cleaned:
        bits = cleaned.split(": ", 1)
        stakes = bits[0]
        names = bits[1]
        label = stakes
    if " VS " not in names:
        return {"kind": "segment", "label": "ANNOUNCED", "names": [], "text": segment_text(raw), "belt": "", "icon": "mic"}
    if " FOR THE " in names:
        names, stakes = names.split(" FOR THE ", 1)
        label = stakes
    # F4W writes stakes after the names: "X VS Y in a men's Money in the Bank qualifying match".
    if " IN A " in names:
        bits = names.split(" IN A ", 1)
        tail = bits[1]
        if "QUALIF" in tail or "TITLE" in tail or "CHAMPIONSHIP" in tail or "MITB" in tail or "MONEY IN THE BANK" in tail:
            names = bits[0]
            if stakes == "":
                stakes = tail
                label = stakes
    if "MONEY IN THE BANK" in stakes or "MITB" in stakes:
        label = "MITB QUALIFIER" if "QUALIF" in stakes else "MITB LADDER MATCH"
        icon = "mitb"
    elif "QUALIF" in stakes or "CONTENDER" in stakes or "NON-TITLE" in stakes or "NON TITLE" in stakes:
        label = "NON-TITLE MATCH" if "NON" in stakes else "CONTENDER MATCH" if "CONTENDER" in stakes else "QUALIFIER"
    else:
        # Only explicit title/championship stakes, not 'Champion X vs Y'.
        if "TITLE" in stakes or "CHAMPIONSHIP" in stakes:
            for meta in TITLES:
                if meta[0] in stakes:
                    label = meta[1]
                    belt = meta[2]
                    break
        for token, caption, art in [["STEEL CAGE", "STEEL CAGE", "cage"], ["LADDER", "LADDER MATCH", "ladder"], ["ROYAL RUMBLE", "ROYAL RUMBLE", "rumble"]]:
            if token in stakes:
                label = caption
                icon = art
    sides = [n.replace(" (C)", "").strip() for n in names.split(" VS ")]
    if len(sides) == 3 and label == "SINGLES MATCH":
        label = "TRIPLE THREAT"
        icon = "triple"
    if any([" & " in n or ", " in n for n in sides]) and label == "SINGLES MATCH":
        label = "TAG TEAM MATCH"
        icon = "tag"
    if belt == "" and len(sides) == 2 and label == "SINGLES MATCH":
        joined = " ".join(sides)
        for meta in CHAMPIONS:
            if meta[0] in joined:
                label = meta[1]
                belt = meta[2]
    return {"kind": "match", "label": label, "names": sides, "text": raw, "belt": belt, "icon": icon}

def select_show(shows, cfg):
    chosen = None
    for show in shows:
        if cfg["brand"] != "AUTO" and show["brand"] != cfg["brand"]:
            continue
        # Future adapters may supply kind='ple'; real dated PLEs compete with
        # weekly shows by start date. No fabricated PLE calendar is installed.
        if chosen == None or show["day"] < chosen["day"]:
            chosen = show
    return chosen

def visible_items(show):
    # Matches first so a title bout is never buried under "to speak" pages.
    items = show["items"]
    matches = [i for i in items if i["kind"] == "match"]
    other = [i for i in items if i["kind"] != "match"]
    if len(other) > 1:
        lines = [str(i.get("text", "")) for i in other]
        packed = {"kind": "segment", "label": "LIVE", "names": [], "text": lines[0], "texts": lines, "belt": "", "icon": "mic"}
        return matches + [packed]
    return matches + other
