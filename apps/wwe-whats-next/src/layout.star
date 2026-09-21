# Miniature match-card. Black field, 2px brand rail, names as the hero.
WHITE = "#F4F7FF"
MUTED = "#8B93A7"
GOLD = "#E7B43A"
BG = "#050506"
LEFT = 14
RIGHT = 180
FONT_HEIGHT = {"10x16": 16, "7x12": 12, "6x8": 8, "5x7": 7, "4x7": 7, "4x5": 5}
BELTS = {
    "worldwhite": "belts/worldwhite.png",
    "world": "belts/world.png",
    "icwhite": "belts/icwhite.png",
    "ic": "belts/ic.png",
    "uswhite": "belts/uswhite.png",
    "us": "belts/us.png",
    "womentag": "belts/womentag.png",
    "worldtag": "belts/worldtag.png",
    "wwetag": "belts/wwetag.png",
    "nawhite": "belts/nawhite.png",
    "na": "belts/na.png",
    "nxtwhite": "belts/nxtwhite.png",
    "nxttag": "belts/nxttag.png",
    "nxt": "belts/nxt.png",
    "women": "belts/women.png",
    "wwe": "belts/wwe.png",
}

def fit(c, text, width, fonts):
    s = str(text).upper()
    for f in fonts:
        if c.text_width(s, f) <= width:
            return [s, f]
    f = fonts[-1]
    for n in range(len(s), -1, -1):
        if c.text_width(s[:n] + "..", f) <= width:
            return [s[:n].rstrip() + "..", f]
    return ["", f]

def text(c, s, x, y, width, fonts = ["5x7", "4x5"], color = WHITE, align = "left"):
    result = fit(c, s, width, fonts)
    if result[0] == "":
        return
    c.text(result[0], x, y, font = result[1], color = color, align = align)

def last_name(s):
    parts = str(s).upper().replace(",", " ").split()
    if not parts:
        return ""
    return parts[len(parts) - 1]

def short_side(s):
    s = str(s).upper()
    if " & " in s:
        bits = []
        for n in s.split(" & "):
            bits.append(last_name(n))
        return " & ".join(bits)
    return s

def brand_col(show):
    return COLORS.get(show["brand"], WHITE)

def ground(c, col):
    c.fill(BG)
    # 3px brand rail at the safe-zone edge. Not a full-screen box.
    c.rect(10, 0, 12, 31, fill = col)

def slot_label(item, index):
    if item.get("belt"):
        return str(item["label"]).upper()
    icon = item.get("icon", "")
    if icon == "mitb":
        return str(item["label"]).upper()
    if icon == "cage":
        return "STEEL CAGE"
    if icon == "ladder":
        return str(item["label"]).upper()
    if item["kind"] == "segment":
        return "LIVE"
    if index == 0:
        return "MAIN EVENT"
    return str(item.get("label", "MATCH")).upper()

def eyebrow(c, show, item, index, total, x0 = LEFT, x1 = RIGHT):
    col = brand_col(show)
    brand = show["brand"]
    slot = slot_label(item, index)
    pos = str(index + 1) + "/" + str(total)
    posw = c.text_width(pos, "4x5")
    text(c, pos, x1, 2, 24, ["4x5"], MUTED, "right")
    # 'RAW MAIN EVENT' is 65px at 4x5. Brand in accent, slot in white.
    bw = c.text_width(brand, "4x5")
    text(c, brand, x0, 2, 70, ["4x5"], col)
    gap = x0 + bw + 4
    remain = x1 - posw - 4 - gap
    if remain > 12:
        text(c, slot, gap, 2, remain, ["4x5"], WHITE)

def vs_join(c, names, x0, x1, y, fonts, name_col, vs_col):
    # Draw NAME VS NAME [VS NAME] on one row. Largest font that fits.
    n = []
    for item in names:
        n.append(str(item).upper())
    for font in fonts:
        vs_w = c.text_width("VS", font)
        widths = []
        for item in n:
            widths.append(c.text_width(item, font))
        gap = 3
        total = 0
        for w in widths:
            total = total + w
        total = total + vs_w * (len(n) - 1) + gap * (2 * (len(n) - 1))
        if total <= x1 - x0:
            x = x0
            for i in range(len(n)):
                c.text(n[i], x, y, font = font, color = name_col)
                x = x + widths[i] + gap
                if i < len(n) - 1:
                    c.text("VS", x, y, font = font, color = vs_col)
                    x = x + vs_w + gap
            return True
    return False

def pair_block(c, left, right, x0, x1, y, col, vs_col):
    lefts = [str(left).upper(), short_side(left), last_name(left)]
    rights = [str(right).upper(), short_side(right), last_name(right)]
    # One hero line of full names first. Last-name clipping is a last resort.
    if vs_join(c, [lefts[0], rights[0]], x0, x1, y, ["6x8", "5x7", "4x7"], col, vs_col):
        return
    width = x1 - x0
    two_y = 10 if y + 17 > 26 else y
    for font in ["6x8", "5x7", "4x7", "4x5"]:
        if c.text_width(lefts[0], font) <= width and c.text_width(rights[0], font) <= width - c.text_width("VS ", font):
            c.text(lefts[0], x0, two_y, font = font, color = col)
            c.text("VS", x0, two_y + FONT_HEIGHT[font] + 1, font = font, color = vs_col)
            vw = c.text_width("VS", font) + 3
            c.text(rights[0], x0 + vw, two_y + FONT_HEIGHT[font] + 1, font = font, color = col)
            return
    for i in range(1, 3):
        if vs_join(c, [lefts[i], rights[i]], x0, x1, y, ["6x8", "5x7", "4x7"], col, vs_col):
            return
    mid = (x0 + x1) // 2
    text(c, lefts[2], x0, y, mid - x0 - 8, ["5x7", "4x5"], col)
    text(c, "VS", mid, y + 1, 14, ["4x5"], vs_col, "center")
    text(c, rights[2], mid + 10, y, x1 - (mid + 10), ["5x7", "4x5"], col)

def multi_block(c, names, x0, x1, y, col, vs_col):
    full = []
    short = []
    for n in names:
        full.append(str(n).upper())
        short.append(last_name(n))
    if vs_join(c, full, x0, x1, y, ["5x7", "4x7"], col, vs_col):
        return
    if vs_join(c, short, x0, x1, y, ["6x8", "5x7", "4x7"], col, vs_col):
        return
    # Two lines: first two on line 1, the rest on line 2.
    if vs_join(c, short[:2], x0, x1, y, ["5x7", "4x5"], col, vs_col):
        if len(short) > 2:
            vs_join(c, short[2:], x0, x1, y + 9, ["5x7", "4x5"], col, vs_col)
        return
    text(c, " VS ".join(short), x0, y, x1 - x0, ["4x5"], col)

def match_page(c, show, item, index, total, cfg):
    col = brand_col(show)
    names = item["names"]
    if item["belt"] and len(names) == 2:
        c.fill(BG)
        c.image(BELTS[item["belt"]], 10, 0)
        pos = str(index + 1) + "/" + str(total)
        text(c, pos, RIGHT, 2, 24, ["4x5"], MUTED, "right")
        text(c, slot_label(item, index), 91, 2, 70, ["4x5"], GOLD)
        pair_block(c, names[0], names[1], 91, RIGHT, 9, WHITE, col)
        return
    ground(c, col)
    eyebrow(c, show, item, index, total)
    if item["kind"] == "segment":
        lines = item.get("texts")
        if type(lines) != "list" or len(lines) == 0:
            lines = [item["text"]]
        if len(lines) == 1:
            text(c, lines[0], LEFT, 14, RIGHT - LEFT, ["6x8", "5x7", "4x5"], WHITE)
        else:
            text(c, lines[0], LEFT, 12, RIGHT - LEFT, ["5x7", "4x5"], WHITE)
            text(c, lines[1], LEFT, 22, RIGHT - LEFT, ["5x7", "4x5"], WHITE)
        return
    if len(names) >= 3:
        multi_block(c, names, LEFT, RIGHT, 14, WHITE, col)
        return
    if len(names) == 2:
        pair_block(c, names[0], names[1], LEFT, RIGHT, 14, WHITE, col)
        return
    text(c, item.get("text", item.get("label", "")), LEFT, 14, RIGHT - LEFT, ["6x8", "5x7", "4x5"], WHITE)

def overview_page(c, show, cfg):
    col = brand_col(show)
    ground(c, col)
    brand = show["brand"]
    text(c, brand, LEFT, 2, 110, ["6x8"], col)
    date = show.get("date", "")
    date_w = 0
    if date != "":
        text(c, date, RIGHT, 2, 70, ["6x8", "5x7", "4x5"], WHITE, "right")
        date_w = c.text_width(date, "6x8")
    bw = c.text_width(brand, "6x8")
    tag_x = LEFT + bw + 4
    tag_w = c.text_width("WHATS NEXT", "4x5")
    if tag_x + tag_w + 6 <= RIGHT - date_w:
        text(c, "WHATS NEXT", tag_x, 4, tag_w + 2, ["4x5"], MUTED)
    place = show.get("venue", "")
    if place == "":
        place = show.get("city", "")
    clock = show.get("time", "")
    if clock == "TIME TBA":
        clock = ""
    if place != "" and clock != "":
        text(c, place, LEFT, 12, 120, ["5x7", "4x5"], WHITE)
        text(c, clock, RIGHT, 12, 44, ["5x7", "4x5"], GOLD, "right")
    elif place != "":
        text(c, place, LEFT, 12, RIGHT - LEFT, ["5x7", "4x5"], WHITE)
    elif clock != "":
        text(c, clock, RIGHT, 12, 44, ["5x7", "4x5"], GOLD, "right")
    matches = len([i for i in show["items"] if i["kind"] == "match"])
    count = str(matches) + (" MATCH" if matches == 1 else " MATCHES")
    ple = show.get("ple")
    has_ple = type(ple) == "dict" and str(ple.get("name", "")) != ""
    if has_ple:
        # Gold plate, separate from the weekly card. Dark ink on #E7B43A.
        c.rect(13, 21, 191, 31, fill = GOLD)
        c.rect(13, 21, 191, 21, fill = "#101018")
        ink = "#101018"
        pdate = str(ple.get("date", "")).upper()
        pd_w = 0
        if pdate != "":
            text(c, pdate, RIGHT, 23, 50, ["6x8", "5x7", "4x5"], ink, "right")
            pd_w = c.text_width(pdate, "6x8")
        name = str(ple["name"]).upper()
        name_w = RIGHT - pd_w - 6 - LEFT
        if name_w > 12:
            text(c, name, LEFT, 23, name_w, ["6x8", "5x7", "4x5"], ink)
        if place == "":
            text(c, count, LEFT, 13, 70, ["4x5"], GOLD)
        return
    text(c, count, LEFT, 24, 70, ["4x5"], GOLD)
    extra = LEFT + c.text_width(count, "4x5") + 4
    if extra + c.text_width("ANNOUNCED", "4x5") <= 150:
        text(c, "ANNOUNCED", extra, 24, 70, ["4x5"], MUTED)

def message(c, cfg, headline, sub):
    brand = cfg["brand"] if cfg["brand"] in BRANDS else "WWE"
    col = COLORS[brand]
    ground(c, col)
    text(c, brand, LEFT, 2, 70, ["4x5"], col)
    text(c, "WHATS NEXT", RIGHT, 2, 90, ["4x5"], MUTED, "right")
    text(c, headline, LEFT, 12, RIGHT - LEFT, ["6x8", "5x7"], WHITE)
    text(c, sub, LEFT, 24, RIGHT - LEFT, ["4x5"], MUTED)

def draw(c, ctx, slot):
    cfg = settings(ctx)
    if not cfg["valid"]:
        message(c, cfg, "CHECK SETTINGS", "CHOOSE A WWE BRAND")
        return
    show = select_show(fetch_shows(cfg, ctx), cfg)
    if show == None:
        message(c, cfg, "CARD UNAVAILABLE", "CHECK BACK SOON")
        return
    if slot < 0:
        overview_page(c, show, cfg)
        return
    items = visible_items(show)
    if not items:
        message(c, cfg, "NO MATCHES ANNOUNCED", "CHECK BACK SOON")
        return
    # Four card pages, always the first four announced items. Minute-banking
    # hid title matches behind leftover TBA. Longer lists still do not wrap.
    index = slot
    if index >= len(items):
        leftover_page(c, show, cfg)
        return
    match_page(c, show, items[index], index, len(items), cfg)

def leftover_page(c, show, cfg):
    col = brand_col(show)
    ground(c, col)
    text(c, show["brand"], LEFT, 2, 70, ["4x5"], col)
    text(c, "WHATS NEXT", RIGHT, 2, 90, ["4x5"], MUTED, "right")
    text(c, "MORE MATCHES TBA", LEFT, 12, RIGHT - LEFT, ["6x8", "5x7"], WHITE)
    text(c, "CHECK BACK SOON", LEFT, 24, RIGHT - LEFT, ["4x5"], MUTED)

def result_star(c, x, y, col):
    c.sprite(["..Y..", "YYYYY", ".YYY.", "Y.Y.Y"], x, y, legend = {"Y": col})

def result_outcome(item):
    outcome = item.get("outcome", "")
    if outcome == "retain":
        return "RETAINS"
    if outcome == "new":
        return "NEW CHAMPION"
    if outcome == "draw":
        return "DRAW"
    if outcome == "nocontest":
        return "NO CONTEST"
    losers = item.get("losers", [])
    prefix = "DQ " if outcome == "dq" else "DEF. "
    if not losers:
        return prefix.strip() if outcome == "dq" else "FINAL"
    if len(losers) == 1:
        return prefix + losers[0]
    joined = prefix + " & ".join(losers)
    return joined

def result_page(c, show, item, cfg):
    col = brand_col(show)
    belt = item.get("belt", "")
    winner = str(item.get("winner", "")).upper()
    outcome = item.get("outcome", "")
    slot = "MAIN EVENT" if item.get("main") and belt == "" else str(item.get("label", "FINAL")).upper()
    brand = show["brand"]
    if slot.startswith(brand + " "):
        slot = slot[len(brand) + 1:]
    # Same 72x32 Champions belt as title-match cards. Winner sits in the
    # remaining 89px at x=91. 'STEPHANIE VAQUER' is 93px at 5x7, so the
    # ladder drops to 4x5 or the last name.
    if belt != "" and winner != "" and belt in BELTS:
        c.fill(BG)
        c.image(BELTS[belt], 10, 0)
        text(c, "FINAL", RIGHT, 2, 28, ["4x5"], GOLD, "right")
        final_w = c.text_width("FINAL", "4x5")
        label_w = RIGHT - final_w - 4 - 91
        if label_w > 12:
            text(c, slot, 91, 2, label_w, ["4x5"], GOLD)
        hero = winner
        if c.text_width(winner, "5x7") > RIGHT - 91:
            hero = last_name(winner)
        text(c, hero, 91, 10, RIGHT - 91, ["6x8", "5x7", "4x7", "4x5"], WHITE)
        line = result_outcome(item)
        if line != "":
            tone = GOLD if outcome in ["retain", "new"] else WHITE
            text(c, line, 91, 22, RIGHT - 91, ["5x7", "4x5"], tone)
        return
    ground(c, col)
    bw = c.text_width(brand, "4x5")
    text(c, brand, LEFT, 2, 50, ["4x5"], col)
    text(c, "FINAL", RIGHT, 2, 28, ["4x5"], GOLD, "right")
    final_w = c.text_width("FINAL", "4x5")
    label_x = LEFT + bw + 4
    label_w = RIGHT - final_w - 4 - label_x
    if label_w > 12:
        text(c, slot, label_x, 2, label_w, ["4x5"], WHITE)
    if outcome in ["draw", "nocontest"] or winner == "":
        hero = "NO CONTEST" if outcome == "nocontest" else "DRAW"
        text(c, hero, LEFT, 12, RIGHT - LEFT, ["6x8", "5x7"], WHITE)
        names = item.get("losers", [])
        if names:
            text(c, " VS ".join(names), LEFT, 23, RIGHT - LEFT, ["5x7", "4x5"], MUTED)
        return
    result_star(c, LEFT, 13, GOLD)
    text(c, winner, LEFT + 8, 12, RIGHT - LEFT - 8, ["6x8", "5x7", "4x7", "4x5"], WHITE)
    line = result_outcome(item)
    if line == "":
        return
    tone = GOLD if outcome in ["retain", "new"] else WHITE
    if outcome in ["win", "dq"] and c.text_width(line, "4x5") > RIGHT - LEFT:
        losers = item.get("losers", [])
        if len(losers) >= 2:
            line = ("DQ " if outcome == "dq" else "DEF. ") + str(len(losers)) + " OTHERS"
        elif losers:
            line = ("DQ " if outcome == "dq" else "DEF. ") + last_name(losers[0])
    text(c, line, LEFT, 23, RIGHT - LEFT, ["5x7", "4x5"], tone)

def load_results(cfg, ctx, show):
    if not cfg["results"] or show == None:
        return []
    return fetch_results(cfg, ctx, show["brand"])

def draw_result(c, ctx, index):
    cfg = settings(ctx)
    if not cfg["valid"]:
        message(c, cfg, "CHECK SETTINGS", "CHOOSE A WWE BRAND")
        return
    show = select_show(fetch_shows(cfg, ctx), cfg)
    if show == None:
        message(c, cfg, "CARD UNAVAILABLE", "CHECK BACK SOON")
        return
    found = load_results(cfg, ctx, show)
    if index >= len(found):
        if found:
            result_empty_page(c, show, cfg)
        else:
            leftover_page(c, show, cfg)
        return
    result_page(c, show, found[index], cfg)

def result_empty_page(c, show, cfg):
    col = brand_col(show)
    ground(c, col)
    text(c, show["brand"], LEFT, 2, 70, ["4x5"], col)
    text(c, "NO OTHER TITLES", LEFT, 12, RIGHT - LEFT, ["6x8", "5x7"], WHITE)
    text(c, "CHECK BACK SOON", LEFT, 24, RIGHT - LEFT, ["4x5"], MUTED)

def overview(c, ctx):
    draw(c, ctx, -1)

def card1(c, ctx):
    draw(c, ctx, 0)

def card2(c, ctx):
    draw(c, ctx, 1)

def card3(c, ctx):
    draw(c, ctx, 2)

def card4(c, ctx):
    draw(c, ctx, 3)

def result1(c, ctx):
    draw_result(c, ctx, 0)

def result2(c, ctx):
    draw_result(c, ctx, 1)

def result3(c, ctx):
    draw_result(c, ctx, 2)
