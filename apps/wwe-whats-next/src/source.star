# Source adapter. Only explicit, dated WWE lineup headings followed by a list
# are accepted. Never infer a card from predictions, results, or article prose.
# Lineup uses two RSS URLs. WWE events fills a missing city and the next PLE.
FEED = "https://www.f4wonline.com/feed/"
FIGHTFUL_FEED = "https://www.fightful.com/feed/"
WWE_EVENTS = "https://www.wwe.com/events/results/all-events/all-dates/0/0/all/US"

def between(s, start, end):
    a = s.find(start)
    if a < 0:
        return ""
    b = s.find(end, a + len(start))
    return s[a + len(start):b] if b >= 0 else ""

def plain(s):
    # Bound work before walking the markup. Headings/list entries only.
    text = ""
    for fragment in s[:5000].split("<"):
        text = text + (fragment.split(">", 1)[1] if ">" in fragment else fragment)
    pairs = [["&amp;", "&"], ["&#038;", "&"], ["&#8217;", "'"], ["&#039;", "'"], ["&#39;", "'"], ["&apos;", "'"], ["&#8216;", "'"], ["’", "'"], ["‘", "'"], ["&#8211;", "-"], ["&#8212;", "-"], ["–", "-"], ["—", "-"], ["&#8220;", '"'], ["&#8221;", '"'], ["&quot;", '"'], ["&nbsp;", " "], ["\u00a0", " "], ["é", "e"], ["á", "a"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"]]
    for p in pairs:
        text = text.replace(p[0], p[1])
    return " ".join(text.upper().split())

def heading_brand(head):
    h = str(head)
    for b in BRANDS:
        if h.startswith("WWE " + b + " (") or h.startswith(b + " (") or h.startswith("WWE " + b + " LINEUP"):
            return b
    return ""

def keep_show(shows, show):
    # Same brand+day: keep the longer announced list so a later update
    # replaces an earlier incomplete card. Never mix two weeks together.
    for s in shows:
        if s["brand"] == show["brand"] and s["day"] == show["day"]:
            if len(show["items"]) > len(s["items"]):
                s["items"] = show["items"]
                s["source"] = show["source"]
            if s["city"] == "":
                s["city"] = show.get("city", "")
            if s["time"] == "":
                s["time"] = show.get("time", "")
            return
    shows.append(show)

def parse_feed(body, nowday, source = "F4W"):
    shows = []
    # A truncated feed is not evidence of a complete announced card.
    if type(body) != "string" or "</rss>" not in body or len(body) > 1500000:
        return shows
    for item in body.split("<item>")[1:51]:
        title = plain(between(item, "<title>", "</title>"))
        if any([bad in title for bad in ["RESULTS", "PREDICTION", "SPOILER", "ON THIS DAY"]]):
            continue
        published = between(item, "<pubDate>", "</pubDate>")
        content = between(item, "<content:encoded><![CDATA[", "]]></content:encoded>")
        if not content:
            continue
        # A lineup list must immediately follow a dated show heading or paragraph.
        # Fightful uses <p><strong>WWE SmackDown (9/25)</strong></p>, not <h2>.
        # F4W updates sometimes use "WWE Raw lineup for Monday, September 21, 2026".
        parts = content.split("<ul")
        for pi in range(1, min(len(parts), 16)):
            before = parts[pi - 1].rstrip()
            start = max(before.rfind("<h2"), before.rfind("<h3"), before.rfind("<p>"), before.rfind("<p "))
            if start < 0:
                continue
            head = plain(before[start:])
            part = parts[pi]
            brand = heading_brand(head)
            if not brand:
                continue
            date = date_from_heading(head, published)
            # Keep the show through its UTC calendar day. Weekly TV is 8PM ET,
            # and UTC midnight is 7PM CDT the evening before — dropping at
            # <= nowday made Monday Raw vanish before it even started.
            if date == None or date["day"] < nowday or date["day"] > nowday + 14:
                continue
            ul = part.split("</ul>", 1)[0] if "</ul>" in part else ""
            if not ul:
                continue
            rows = []
            for li in ul.split("<li")[1:25]:
                raw = plain(between(li, ">", "</li>"))
                if raw:
                    rows.append(normalize_item(raw))
            if rows:
                extra = extras_from_item(head, plain(title + " " + between(item, "<description>", "</description>") + " " + content[:2000]))
                keep_show(shows, {"brand": brand, "day": date["day"], "date": date["label"], "time": extra["time"], "city": extra["city"], "venue": extra["venue"], "items": rows, "source": source, "url": between(item, "<link>", "</link>"), "kind": "weekly"})
    return shows

def wwe_event_brand(window):
    wu = str(window).upper()
    best = -1
    brand = ""
    pairs = [["FRIDAY NIGHT SMACKDOWN", "SMACKDOWN"], ["MONDAY NIGHT RAW", "RAW"], ["NXT LIVE", "SKIP"], ["NXT", "NXT"]]
    for pair in pairs:
        i = wu.rfind(pair[0])
        if i > best:
            best = i
            brand = pair[1]
    if brand == "SKIP":
        return ""
    if best >= 0 and "RAW" in wu[best:best + 48] and "SMACKDOWN" in wu[best:best + 48]:
        return ""
    return brand

def parse_wwe_events(body):
    # Dated WWE.com event cards. City only when brand+calendar day match.
    found = []
    if type(body) != "string" or "venue-container" not in body or len(body) > 1500000:
        return found
    marker = 'class="venue-container">'
    pos = 0
    for _ in range(80):
        i = body.find(marker, pos)
        if i < 0:
            return found
        pos = i + len(marker)
        end = body.find("<", pos)
        if end < 0:
            continue
        city = plain(body[pos:end])
        if city.find(", ") < 2:
            continue
        window = body[max(0, i - 1800):i]
        brand = wwe_event_brand(window)
        di = window.rfind('datetime="')
        if brand == "" or di < 0:
            continue
        close = window.find('"', di + 10)
        dt = window[di + 10:close] if close > di + 10 else ""
        if len(dt) < 10:
            continue
        bits = dt[:10].split("-")
        if len(bits) != 3 or not bits[0].isdigit() or not bits[1].isdigit() or not bits[2].isdigit():
            continue
        y = int(bits[0])
        m = int(bits[1])
        d = int(bits[2])
        if m < 1 or m > 12 or d < 1:
            continue
        day = day_number(y, m, d)
        keep_show(found, {"brand": brand, "day": day, "date": "", "time": "", "city": city, "venue": "", "items": [], "source": "WWE", "kind": "place"})
    return found

def strip_day_suffix(w):
    for suf in ["TH", "ST", "ND", "RD"]:
        if len(w) > len(suf) and w.endswith(suf) and w[:len(w) - len(suf)].isdigit():
            return w[:len(w) - len(suf)]
    return w

def ple_label(title):
    t = str(title).upper()
    if "ROAD TO" in t:
        return ""
    for p in ["WWE/", "AAA/", "NXT ", "WWE "]:
        t = t.replace(p, "")
    t = t.strip(" -/")
    if "MONEY IN THE BANK" in t:
        return "MITB"
    if "WORLDS COLLIDE" in t:
        return "WORLDS COLLIDE"
    if "SURVIVOR" in t:
        return "SURVIVOR"
    if "WRESTLEMANIA" in t:
        return "WRESTLEMANIA"
    if "SUMMERSLAM" in t:
        return "SUMMERSLAM"
    if "ROYAL RUMBLE" in t:
        return "ROYAL RUMBLE"
    if "CROWN JEWEL" in t:
        return "CROWN JEWEL"
    if "WRESTLEPALOOZA" in t:
        return "WRESTLEPALOOZA"
    if "ELIMINATION CHAMBER" in t:
        return "CHAMBER"
    if "BACKLASH" in t:
        return "BACKLASH"
    if "BAD BLOOD" in t:
        return "BAD BLOOD"
    return t.split(":")[0].strip()

def parse_next_ple(body, nowday, year, month):
    # WWE trending cards only. One future PLE: earliest dated title.
    best = None
    if type(body) != "string" or "le-card-meta-title" not in body:
        return None
    parts = body.split("le-card-meta-title")
    for pi in range(1, min(len(parts), 12)):
        chunk = parts[pi][:800]
        name = ple_label(plain(between(chunk, ">", "</h3>")))
        if name == "":
            continue
        date_s = plain(between(chunk, 'le-card-meta-date">', "</p>"))
        words = date_s.replace(",", " ").split()
        m = 0
        d = 0
        for i in range(len(words)):
            token = strip_day_suffix(words[i].strip(".,"))
            for mi in range(12):
                if token in [MONTHS[mi], MONTHS[mi][:3], "SEPT" if mi == 8 else ""]:
                    m = mi + 1
            if m and token.isdigit() and d == 0:
                d = int(token)
        if m < 1 or d < 1:
            continue
        day = day_number(year, m, d)
        if day < nowday:
            if m < month:
                day = day_number(year + 1, m, d)
            else:
                continue
        if day < nowday:
            continue
        city = plain(between(chunk, 'le-card-meta-venue">', "</p>")).strip(" ,")
        event = {"name": name, "date": MONTHS[m - 1][:3] + " " + str(d), "city": city, "day": day}
        if best == None or event["day"] < best["day"]:
            best = event
    return best

def fill_wwe_meta(shows, ctx):
    if not shows:
        return
    response = http.get(WWE_EVENTS, ttl_seconds = 900)
    if response["status_code"] != 200:
        return
    body = response.get("body", "")
    places = parse_wwe_events(body)
    ple = parse_next_ple(body, ctx.now.unix // 86400, ctx.now.year, ctx.now.month)
    for s in shows:
        for p in places:
            if p["brand"] != s["brand"] or p["day"] != s["day"]:
                continue
            if s.get("city", "") == "" and p.get("city", "") != "":
                s["city"] = p["city"]
            break
        if ple != None:
            s["ple"] = ple

def apply_weekly_time(shows):
    # Lineup articles often omit start time. Weekly RAW/SD/NXT air at 8PM ET.
    for s in shows:
        if s.get("time", "") == "" and s["brand"] in BRANDS:
            s["time"] = "8PM ET"

def fetch_shows(cfg, ctx):
    query = "WWE" if cfg["brand"] == "AUTO" else "WWE " + cfg["brand"]
    providers = [[FIGHTFUL_FEED, "FTFL"], [FEED, "F4W"]] if cfg["brand"] == "SMACKDOWN" else [[FEED, "F4W"], [FIGHTFUL_FEED, "FTFL"]]
    shows = []
    for provider in providers:
        response = http.get(provider[0], params = {"s": query}, ttl_seconds = 900)
        if response["status_code"] == 200:
            found = parse_feed(response.get("body", ""), ctx.now.unix // 86400, provider[1])
            for show in found:
                keep_show(shows, show)
        chosen = select_show(shows, cfg)
        if cfg["brand"] != "AUTO" and chosen != None and chosen["city"] != "" and chosen["time"] != "":
            break
    fill_wwe_meta(shows, ctx)
    apply_weekly_time(shows)
    return shows
