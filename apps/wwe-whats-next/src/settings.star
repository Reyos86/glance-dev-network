# DESIGN. Miniature arena match-card on 192x32. Black field, 2px brand
# rail, compact eyebrow, wrestler names as the hero. No portraits, no
# source chrome, no full-screen header. Title matches with icons reuse
# the WWE Champions 72x32 belt at x=10. Previous-show results reuse that
# City/time from the lineup when present. If the card omits them, WWE.com
# events fills the dated city and the single next PLE on the overview.
# build.py joins these files.
BRANDS = ["RAW", "SMACKDOWN", "NXT"]
COLORS = {"RAW": "#E10600", "SMACKDOWN": "#3D7EFF", "NXT": "#E7B43A", "WWE": "#D8DEE8"}
DEEP = {"RAW": "#6B0000", "SMACKDOWN": "#10244A", "NXT": "#3A2E10", "WWE": "#101018"}
INK = {"RAW": "#FFFFFF", "SMACKDOWN": "#FFFFFF", "NXT": "#101018", "WWE": "#101018"}
STATES = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "IA", "ID", "IL", "IN", "KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN", "MO", "MS", "MT", "NC", "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA", "WI", "WV", "WY", "DC"]
STATE_NAMES = {"ALABAMA": "AL", "ALASKA": "AK", "ARIZONA": "AZ", "ARKANSAS": "AR", "CALIFORNIA": "CA", "COLORADO": "CO", "CONNECTICUT": "CT", "DELAWARE": "DE", "FLORIDA": "FL", "GEORGIA": "GA", "HAWAII": "HI", "IDAHO": "ID", "ILLINOIS": "IL", "INDIANA": "IN", "IOWA": "IA", "KANSAS": "KS", "KENTUCKY": "KY", "LOUISIANA": "LA", "MAINE": "ME", "MARYLAND": "MD", "MASSACHUSETTS": "MA", "MICHIGAN": "MI", "MINNESOTA": "MN", "MISSISSIPPI": "MS", "MISSOURI": "MO", "MONTANA": "MT", "NEBRASKA": "NE", "NEVADA": "NV", "NEW HAMPSHIRE": "NH", "NEW JERSEY": "NJ", "NEW MEXICO": "NM", "NEW YORK": "NY", "NORTH CAROLINA": "NC", "NORTH DAKOTA": "ND", "OHIO": "OH", "OKLAHOMA": "OK", "OREGON": "OR", "PENNSYLVANIA": "PA", "RHODE ISLAND": "RI", "SOUTH CAROLINA": "SC", "SOUTH DAKOTA": "SD", "TENNESSEE": "TN", "TEXAS": "TX", "UTAH": "UT", "VERMONT": "VT", "VIRGINIA": "VA", "WASHINGTON": "WA", "WEST VIRGINIA": "WV", "WISCONSIN": "WI", "WYOMING": "WY", "ONTARIO": "ON"}
SKIP_PLACE = ["THE", "A", "AN", "HIS", "HER", "THIS", "THAT", "RAW", "SMACKDOWN", "NXT", "WWE", "OUR", "YOUR", "SOCIAL", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY", "TONIGHT", "TODAY", "LAST", "NEXT", "RIGHT", "HERE", "LIVE", "GOING"]
PLACE_NAMES = {"SAN ANTONIO": "SAN ANTONIO, TX", "ST LOUIS": "ST. LOUIS, MO", "ORLANDO": "ORLANDO, FL", "CHICAGO": "CHICAGO, IL", "LAS VEGAS": "LAS VEGAS, NV", "LOS ANGELES": "LOS ANGELES, CA", "NEW YORK": "NEW YORK, NY", "HOUSTON": "HOUSTON, TX", "ATLANTA": "ATLANTA, GA", "BOSTON": "BOSTON, MA", "PHILADELPHIA": "PHILADELPHIA, PA", "DALLAS": "DALLAS, TX", "DETROIT": "DETROIT, MI", "MIAMI": "MIAMI, FL", "TORONTO": "TORONTO, ON", "NASHVILLE": "NASHVILLE, TN", "PHOENIX": "PHOENIX, AZ", "DENVER": "DENVER, CO", "SEATTLE": "SEATTLE, WA", "TAMPA": "TAMPA, FL", "CHARLOTTE": "CHARLOTTE, NC", "WASHINGTON": "WASHINGTON, DC", "NEW ORLEANS": "NEW ORLEANS, LA", "INDIANAPOLIS": "INDIANAPOLIS, IN", "CORPUS CHRISTI": "CORPUS CHRISTI, TX"}
MONTHS = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

def settings(ctx):
    brand = str(ctx.inputs.get("brand", "AUTO")).upper()
    results = str(ctx.inputs.get("results", "ON")).upper()
    if results == "TRUE":
        results = "ON"
    if results == "FALSE":
        results = "OFF"
    return {"brand": brand, "valid": brand in BRANDS + ["AUTO"], "results": results == "ON"}

def day_number(y, m, d):
    # Gregorian date to Unix day; also handles December/January boundaries.
    y = y - (1 if m <= 2 else 0)
    era = y // 400
    yo = y - era * 400
    mp = m + (-3 if m > 2 else 9)
    return era * 146097 + yo * 365 + yo // 4 - yo // 100 + (153 * mp + 2) // 5 + d - 1 - 719468

def date_from_heading(heading, published):
    words = heading.replace("(", " ").replace(")", " ").replace(",", " ").replace("|", " ").split()
    pub = published.split()
    if len(pub) < 4 or not pub[3].isdigit():
        return None
    year = int(pub[3])
    pubmonth = 0
    for i in range(12):
        if MONTHS[i][:3] == pub[2].upper():
            pubmonth = i + 1
    # Fightful labels its card blocks with US dates such as (9/25).
    expanded = []
    for word in words:
        pieces = word.split("/")
        if len(pieces) in [2, 3] and pieces[0].isdigit() and pieces[1].isdigit() and int(pieces[0]) in range(1, 13):
            expanded.extend([MONTHS[int(pieces[0]) - 1], pieces[1]])
            if len(pieces) == 3:
                if len(pieces[2]) != 4 or not pieces[2].isdigit():
                    return None
                expanded.append(pieces[2])
        else:
            expanded.append(word)
    words = expanded
    for i in range(len(words) - 1):
        month = 0
        for mi in range(12):
            if words[i].rstrip(".") in [MONTHS[mi], MONTHS[mi][:3], "SEPT" if mi == 8 else ""]:
                month = mi + 1
        if month and words[i + 1].isdigit():
            day = int(words[i + 1])
            y = year + (1 if pubmonth == 12 and month == 1 else 0)
            if i + 2 < len(words) and words[i + 2].isdigit() and len(words[i + 2]) == 4:
                y = int(words[i + 2])
            lengths = [31, 29 if y % 4 == 0 and (y % 100 != 0 or y % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
            if day > 0 and day <= lengths[month - 1]:
                return {"day": day_number(y, month, day), "label": MONTHS[month - 1][:3] + " " + str(day), "year": y}
    return None

def extras_from_heading(heading):
    # Only the text AFTER the dated parenthesis is a place/time candidate.
    # Never guess a city from the date itself (JANUARY 2, 2030).
    city = ""
    venue = ""
    time = ""
    h = str(heading).upper()
    rest = h
    cut = h.rfind(")")
    if cut >= 0:
        rest = h[cut + 1:].strip(" -")
    for w in (rest + " " + h).split():
        token = w.strip(".,")
        if len(token) >= 4 and token[0].isdigit() and "/" in token and token.endswith("C"):
            time = token
        if token.endswith("ET") and len(token) >= 3 and token[0].isdigit():
            time = token
        if token in ["8PM", "7PM", "9PM", "10PM"]:
            time = token
    comma = rest.find(", ")
    if comma >= 2 and comma + 4 <= len(rest):
        st = rest[comma + 2:comma + 4]
        if st in STATES:
            lead = rest[:comma].strip(" -")
            for prefix in ["IN ", "AT ", "FROM "]:
                if lead.startswith(prefix):
                    lead = lead[len(prefix):]
            if lead != "" and not lead[0].isdigit():
                city = lead + ", " + st
    return {"city": city, "venue": venue, "time": time}

def parse_place_chunk(chunk):
    lead = chunk.strip(" -")
    for stop in [" AND ", " FOR ", " WITH ", " FOLLOWING ", " AFTER ", " BEFORE ", " ON ", " WILL ", " ITS ", " IT'S "]:
        cut = lead.find(stop)
        if cut > 2:
            lead = lead[:cut]
    comma = lead.find(", ")
    if comma < 2:
        return ""
    name = lead[:comma].strip(" -")
    rest = lead[comma + 2:].strip()
    if name == "" or name.split()[0] in SKIP_PLACE:
        return ""
    st = rest.split()[0].strip(",.") if rest else ""
    if st in STATES:
        return name + ", " + st
    if st in STATE_NAMES:
        return name + ", " + STATE_NAMES[st]
    return ""

def city_from_prose(text):
    # 'episode of Raw from San Antonio, Texas' is a real location.
    # Skip 'last week ... from Mexico City' so prior towns never leak in.
    t = " " + str(text).upper().replace(".", "") + " "
    pos = 0
    for _ in range(12):
        i = -1
        marker = ""
        for m in [" FROM ", " IN ", " AT "]:
            at = t.find(m, pos)
            if at >= 0 and (i < 0 or at < i):
                i = at
                marker = m
        if i < 0:
            return ""
        before = t[max(0, i - 28):i]
        if any([bad in before for bad in ["LAST WEEK", "LAST NIGHT", "YESTERDAY", "LAST YEAR"]]):
            pos = i + 3
            continue
        city = parse_place_chunk(t[i + len(marker):])
        if city != "":
            return city
        after = t[i + len(marker):].strip()
        for key in PLACE_NAMES:
            if after.startswith(key + ",") or after.startswith(key + " ") or after.startswith(key + "!") or after.startswith(key):
                if len(after) == len(key) or after[len(key):len(key) + 1] in [" ", ",", "!", "-"]:
                    return PLACE_NAMES[key]
        pos = i + 3
    return ""

def time_from_prose(text):
    t = str(text).upper().replace("P.M.", "PM").replace("P.M", "PM").replace("A.M.", "AM")
    packed = t.replace(" ", "")
    if "8/7C" in packed:
        return "8/7C"
    if "8E/5P" in packed:
        return "8PM ET"
    words = t.replace(",", " ").split()
    for i in range(len(words)):
        w = words[i].strip(".,")
        if w in ["PM", "AM"] and i > 0 and words[i - 1][0].isdigit():
            clock = words[i - 1].strip(".,") + w
            if i + 1 < len(words) and words[i + 1].strip(".,") in ["ET", "CT", "PT"]:
                return clock + " " + words[i + 1].strip(".,")
            return clock
        if len(w) >= 4 and w[0].isdigit() and "/" in w and w.endswith("C"):
            return w
        if w.endswith("ET") and len(w) >= 3 and w[0].isdigit():
            return w
        if w in ["8PM", "7PM", "9PM", "10PM"]:
            return w
    return ""

def extras_from_item(heading, blurb):
    extra = extras_from_heading(heading)
    hay = str(heading) + " " + str(blurb)
    if extra["city"] == "":
        extra["city"] = city_from_prose(hay)
    if extra["time"] == "":
        extra["time"] = time_from_prose(hay)
    return extra
