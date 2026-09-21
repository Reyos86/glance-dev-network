# Completed-show results. Fightful recap lines use "X def. Y to retain/win".
# Upcoming cards still ignore RESULTS titles. Winners are never inferred
# from "vs" lines, previews, or article prose.
def strip_managers(s):
    out = str(s)
    for _ in range(6):
        a = out.find(" (W/")
        if a < 0:
            break
        b = out.find(")", a)
        if b < 0:
            break
        out = out[:a] + out[b + 1:]
    return " ".join(out.split())

def clean_name(s):
    n = strip_managers(str(s).upper().replace("'", "").replace("’", ""))
    n = n.replace(" (C)", "").replace("(C)", "")
    return " ".join(n.split()).strip(" .")

def result_stakes(stakes):
    label = "MATCH"
    belt = ""
    s = str(stakes).replace("'", "").replace("’", "")
    if "TITLE" in s or "CHAMPIONSHIP" in s:
        for meta in TITLES:
            key = meta[0].replace("'", "").replace("’", "")
            if key in s:
                return [meta[1], meta[2]]
        label = "TITLE MATCH"
    elif "MONEY IN THE BANK" in s or "MITB" in s:
        label = "MITB QUALIFIER"
    return [label, belt]

def parse_result_line(raw):
    s = strip_managers(plain(raw) if "<" in str(raw) else str(raw).upper())
    s = s.replace("'", "").replace("’", "")
    s = " ".join(s.split())
    if s == "":
        return None
    outcome = ""
    if "NO CONTEST" in s:
        outcome = "nocontest"
    elif " DREW " in s or s.endswith(" DRAW") or " A DRAW" in s:
        outcome = "draw"
    elif " DEF. " in s:
        outcome = "win"
    else:
        return None
    stakes = ""
    body = s
    if ": " in s:
        bits = s.split(": ", 1)
        head = bits[0]
        if "TITLE" in head or "CHAMPIONSHIP" in head or "MITB" in head or "MONEY IN THE BANK" in head:
            stakes = head
            body = bits[1]
    meta = result_stakes(stakes)
    label = meta[0]
    belt = meta[1]
    winner = ""
    losers = []
    if outcome == "win":
        parts = body.split(" DEF. ", 1)
        winner = clean_name(parts[0])
        rest = parts[1] if len(parts) > 1 else ""
        for tail in [" TO RETAIN THE TITLES", " TO RETAIN THE TITLE", " TO RETAIN", " TO WIN THE TITLES", " TO WIN THE TITLE", " TO WIN", " TO BECOME THE NEW CHAMPION", " VIA DISQUALIFICATION", " VIA DQ"]:
            rest = rest.replace(tail, " ")
        rest = " ".join(rest.split()).strip(" .")
        if rest != "":
            losers = [clean_name(x) for x in rest.split(" & ")]
            losers = [n for n in losers if n != ""]
        if belt != "":
            if "TO RETAIN" in body or " (C)" in parts[0] or "(C)" in parts[0]:
                outcome = "retain"
            elif "TO WIN" in body or "NEW CHAMPION" in body or " TO BECOME" in body or " (C)" in parts[1] or "(C)" in parts[1]:
                outcome = "new"
        if "VIA DISQUALIFICATION" in body or " VIA DQ" in body:
            if outcome == "win":
                outcome = "dq"
        if winner == "":
            return None
    elif outcome == "draw":
        if " DREW " in body:
            bits = body.split(" DREW ", 1)
            losers = [clean_name(bits[0]), clean_name(bits[1].split(" TO ")[0])]
        elif " VS " in body:
            losers = [clean_name(n) for n in body.split(" VS ")]
            if losers:
                losers[len(losers) - 1] = clean_name(losers[len(losers) - 1].split(" END")[0].split(" GO")[0].split(" DRAW")[0])
    elif outcome == "nocontest":
        if " VS " in body:
            losers = [clean_name(n) for n in body.split(" VS ")]
            if losers:
                losers[len(losers) - 1] = clean_name(losers[len(losers) - 1].split(" END")[0].split(" GO")[0].split(" NO CONTEST")[0])
    return {"kind": "result", "label": label, "belt": belt, "winner": winner, "losers": losers, "outcome": outcome, "main": False, "text": s}

def result_lines(content):
    lines = []
    for li in str(content).split("<li")[1:40]:
        chunk = li.split("<ul")[0]
        if ">" not in chunk:
            continue
        raw = plain(chunk.split(">", 1)[1])
        parsed = parse_result_line(raw)
        if parsed != None:
            lines.append(parsed)
    return lines

def result_brand(title):
    t = str(title).upper()
    if "RESULTS" not in t:
        return ""
    if any([bad in t for bad in ["REVIEW", "PODCAST", "PREDICTION", "SPOILER", "ON THIS DAY"]]):
        return ""
    if "NXT" in t:
        return "NXT"
    if "SMACKDOWN" in t:
        return "SMACKDOWN"
    if "RAW" in t:
        return "RAW"
    return ""

def pick_result_items(matches):
    if not matches:
        return []
    last = len(matches) - 1
    main = matches[last]
    main["main"] = True
    if main["label"] == "MATCH" or main["label"] == "MITB QUALIFIER":
        main["label"] = "MAIN EVENT"
    picked = [main]
    for i in range(last):
        if matches[i]["belt"] != "":
            picked.append(matches[i])
    return picked

def parse_result_feed(body, nowday, brand):
    shows = []
    if type(body) != "string" or "</rss>" not in body or len(body) > 1500000:
        return shows
    for item in body.split("<item>")[1:51]:
        title = plain(between(item, "<title>", "</title>"))
        found = result_brand(title)
        if found != brand:
            continue
        published = between(item, "<pubDate>", "</pubDate>")
        content = between(item, "<content:encoded><![CDATA[", "]]></content:encoded>")
        if not content:
            continue
        date = date_from_heading(title + " " + plain(content[:400]), published)
        if date == None or date["day"] >= nowday or date["day"] < nowday - 21:
            continue
        matches = result_lines(content)
        if not matches:
            continue
        if not any([s["day"] == date["day"] for s in shows]):
            shows.append({"brand": brand, "day": date["day"], "date": date["label"], "items": matches})
    chosen = None
    for show in shows:
        if chosen == None or show["day"] > chosen["day"]:
            chosen = show
    if chosen == None:
        return []
    return pick_result_items(chosen["items"])

def fetch_results(cfg, ctx, brand):
    if not cfg["results"] or brand not in BRANDS:
        return []
    query = "WWE " + brand + " results"
    response = http.get(FIGHTFUL_FEED, params = {"s": query}, ttl_seconds = 900)
    if response["status_code"] != 200:
        return []
    return parse_result_feed(response.get("body", ""), ctx.now.unix // 86400, brand)
