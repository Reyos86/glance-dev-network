# DESIGN: the user's dual-printer SCROLL dashboard, entirely inside x=10..181.
# Auto is state-driven, never time-multiplexed. Bridge local time is authoritative.
COLORS = {"PRINTING": "green", "PREPARING": "green", "PAUSED": "amber", "ERROR": "red", "OFFLINE": "red", "FINISHED": "green", "IDLE": "#BCC6D5"}
MUTED = "#BCC6D5"

def clean(value, fallback = ""):
    if type(value) != "string":
        return fallback
    return " ".join("".join([ch if ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 :-_./%+()" else " " for ch in value[:256].upper().elems()]).split()) or fallback

def clip(c, value, font, width):
    s = clean(value)
    if c.text_width(s, font) <= width:
        return s
    for n in range(len(s), -1, -1):
        if c.text_width(s[:n] + "..", font) <= width:
            return s[:n].rstrip() + ".."
    return ""

def txt(c, s, x, y, width, font = "4x5", color = "white"):
    c.text(clip(c, s, font, width), x, y, font = font, color = color)

def number(v, maximum = 999999):
    if type(v) not in ["int", "float"] or v != v:
        return None
    return int(max(0, min(maximum, v)))

def obj(v):
    return v if type(v) == "dict" else {}

def state(p):
    if p.get("online") == False:
        return "OFFLINE"
    s = clean(p.get("state"))
    return {"RUNNING": "PRINTING", "PREPARE": "PREPARING", "FINISH": "FINISHED", "READY": "IDLE"}.get(s, s if s in COLORS else "ERROR")

def identity(p):
    return clean(p.get("model"), clean(p.get("name"), "BAMBU"))

def job(p):
    return clean(p.get("display_job"), clean(p.get("job"), "UNTITLED PRINT"))

def safe_color(v, fallback = "green"):
    if type(v) != "string":
        return fallback
    h = v.lstrip("#").upper()
    if len(h) not in [6, 8] or any([ch not in "0123456789ABCDEF" for ch in h.elems()]):
        return fallback
    rgb = [int(h[i:i+2], 16) for i in [0, 2, 4]]
    peak = max(rgb)
    # Raise value preserving channel ratios, then add white for low-luminance blue.
    rgb = [int(v * 160 / peak) for v in rgb] if peak > 0 and peak < 160 else rgb
    lum = (rgb[0]*299 + rgb[1]*587 + rgb[2]*114)//1000
    lift = max(0, 120-lum)
    rgb = [min(255, v+lift) for v in rgb]
    digits = "0123456789ABCDEF"
    return "#" + "".join([digits[v//16] + digits[v%16] for v in rgb])

def accent(p):
    s = state(p)
    return safe_color(p.get("active_filament_color"), COLORS[s]) if s in ["PRINTING", "PREPARING"] else COLORS[s]

def clock(v, compact = False):
    s = clean(v)
    # Accept a bridge-formatted local clock or local ISO datetime; never UTC ETA.
    if "T" in s and len(s) >= 16:
        s = s.split("T")[1][:5]
    parts = s.split()
    t = parts[0] if parts else ""
    hm = t.split(":")
    if len(hm) < 2 or not hm[0].isdigit() or not hm[1].isdigit():
        return ""
    hour, minute = int(hm[0]), int(hm[1])
    if hour > 23 or minute > 59:
        return ""
    suffix = parts[1] if len(parts) > 1 and parts[1] in ["AM", "PM"] else ("PM" if hour >= 12 else "AM")
    result = str(hour % 12 or 12) + ":" + ("0" + str(minute))[-2:]
    return result + suffix[0] if compact else result + " " + suffix

def percent(p):
    n = 100 if state(p) == "FINISHED" else number(p.get("progress"), 100)
    return "--%" if n == None else "%d%%" % n

def base(c, color):
    c.fill("black")
    c.rect(10, 1, 11, 30, fill = color)

def message(c, title, sub, color = "amber"):
    base(c, color)
    txt(c, "BAMBU STATUS", 15, 1, 167, color = MUTED)
    txt(c, title, 15, 10, 167, "5x7", color)
    txt(c, sub, 15, 24, 167, color = MUTED)

def cooling(p):
    hot = p.get("hot_components", [])
    names = [clean(x.get("component", x.get("name"))) if type(x) == "dict" else clean(x) for x in hot] if type(hot) in ["list", "dict"] else [clean(hot)]
    parts = []
    for name, key in [("BED", "bed_temp"), ("NOZZLE", "nozzle_temp")]:
        value = number(p.get(key), 500)
        if value != None and (any([name in x for x in names]) or not names):
            parts.append("%s %dC" % (name, value))
    return " / ".join(parts) or "HOT COMPONENTS"

def single(c, p):
    s = state(p)
    color = accent(p)
    base(c, color)
    txt(c, identity(p), 15, 1, 63)
    c.text("COMPLETE" if s == "FINISHED" else s, 181, 1, font = "4x5", color = color, align = "right")
    if s in ["OFFLINE", "ERROR"]:
        txt(c, "PRINTER " + s, 15, 10, 167, "5x7", "red")
        txt(c, "CHECK CONNECTION" if s == "OFFLINE" else "CHECK PRINTER", 15, 24, 167)
        return
    if s == "IDLE":
        txt(c, "COOLING", 15, 10, 167, "5x7", "amber")
        txt(c, cooling(p), 15, 24, 167)
        return
    # Percentage reserves the right edge of the job row; jobs never enter it.
    pct = percent(p)
    pw = c.text_width(pct, "5x7")
    txt(c, job(p), 15, 9, 161-pw, "5x7")
    c.text(pct, 181, 9, font = "5x7", align = "right")
    eta = clock(p.get("estimated_completion_local"))
    line = "COMPLETION UNKNOWN"
    if eta:
        for prefix in ["ESTIMATED COMPLETION: ", "EST COMPLETE ", "COMPLETE "]:
            if c.text_width(prefix + eta, "4x5") <= 167:
                line = prefix + eta
                break
    if s == "PAUSED":
        line = "PAUSED / ON HOLD"
    if s == "FINISHED":
        finished = clock(p.get("completed_at_local", p.get("finished_at_local")))
        line = "FINISHED" + (" " + finished if finished else "")
        if p.get("temperature_warning") == True:
            line = "COOLING " + cooling(p)
    txt(c, line, 15, 18, 167, color = MUTED)
    c.progress_bar(15, 26, 167, 5, 100 if s == "FINISHED" else (number(p.get("progress"), 100) or 0), color = color, bg = "#263345")
    # Optional filament label in the header's middle gap, measured around status.
    label = clean(p.get("active_filament_slot")).replace("DY1", "HT1") + " " + clean(p.get("active_filament_type"))
    if not label.strip():
        layer, total = number(p.get("layer")), number(p.get("total_layers"))
        if layer != None and total != None and total > 0:
            label = "LAYER %d/%d" % (layer, total)
    sw = c.text_width(s, "4x5")
    left = 20 + c.text_width(clip(c, identity(p), "4x5", 63), "4x5")
    if s in ["PRINTING", "PREPARING"] and label.strip() and c.text_width(label, "4x5") + 7 <= 176-sw-left:
        c.rect(left, 2, left+2, 4, fill = color)
        txt(c, label, left+5, 1, 171-sw-left, color = MUTED)

def dual(c, printers):
    c.fill("black")
    for i in range(2):
        p = printers[i]
        y = i*16
        s = state(p)
        color = accent(p)
        c.rect(10, y+1, 11, y+14, fill = color)
        txt(c, identity(p), 15, y, 28)
        status = percent(p) if s == "PRINTING" else ("PREP " + percent(p) if s == "PREPARING" else "PAUSED " + percent(p) if s == "PAUSED" else s)
        txt(c, status, 47, y, 48, color = color)
        eta = clock(p.get("estimated_completion_local"), True) if s in ["PRINTING", "PREPARING"] else ""
        c.text(("ETA " + eta) if eta else "", 181, y, font = "4x5", color = MUTED, align = "right")
        label = job(p) if s in ["PRINTING", "PREPARING", "PAUSED", "FINISHED"] else ("CHECK PRINTER" if s == "ERROR" else "CHECK CONNECTION" if s == "OFFLINE" else "READY")
        txt(c, label, 15, y+6, 167)
        c.progress_bar(15, y+13, 167, 2, number(p.get("progress"), 100) or 0, color = color, bg = "#263345")

def idle(c, printers, data):
    base(c, "green")
    txt(c, "BAMBU", 15, 1, 100, "5x7")
    c.text("READY", 181, 1, font = "5x7", color = "green", align = "right")
    for i in range(len(printers)):
        txt(c, identity(printers[i]) + " READY", 15+i*86, 12, 81, color = MUTED)
    d = obj(data.get("daily_summary"))
    count = number(d.get("completed_prints", d.get("prints_completed", d.get("print_count", d.get("total_prints", d.get("prints")))))) or 0
    mins = number(d.get("observed_print_minutes")) or 0
    duration = "%dH %dM" % (mins//60, mins%60) if mins >= 60 else "%dM" % mins
    line = "TODAY %d PRINT%s / %s" % (count, "" if count == 1 else "S", duration) if count or mins else "READY FOR YOUR NEXT PRINT"
    txt(c, line, 15, 24, 167)

def inventory(c, printers):
    c.fill("black")
    # Five fixed 28px cells: both AMS units and HT1 are visible without rotation.
    for row in range(len(printers)):
        p = printers[row]
        y = row*16
        txt(c, identity(p), 15, y+1, 22, color = MUTED)
        slots = p.get("ams_slots", [])
        if type(slots) != "list" or not slots:
            txt(c, "NO AMS DATA", 42, y+5, 140)
            continue
        for i in range(min(5, len(slots))):
            slot = obj(slots[i])
            x = 42+i*28
            label = clean(slot.get("slot", slot.get("id", slot.get("name", "A"+str(i+1))))).replace("DY1", "HT1")
            col = safe_color(slot.get("color", slot.get("filament_color")), "#BCC6D5")
            active = slot.get("active") == True or label == clean(p.get("active_filament_slot")).replace("DY1", "HT1")
            c.rect(x, y+2, x+3, y+5, fill = col)
            txt(c, label, x+6, y+1, 21, color = "white" if active else MUTED)
            txt(c, clean(slot.get("type", slot.get("filament_type")), "--"), x, y+8, 26)
            if active:
                c.line(x, y+14, x+24, y+14, col)

def diagnostics(c, printers, data):
    base(c, "green")
    d = obj(data.get("diagnostics"))
    age = number(d.get("age_seconds", data.get("age_seconds")))
    txt(c, "BRIDGE OK" + (" / %dS" % age if age != None else ""), 15, 1, 167, "5x7", "green")
    for i in range(len(printers)):
        p = printers[i]
        txt(c, identity(p) + (" ONLINE" if p.get("online") == True else " OFFLINE"), 15+i*86, 13, 81, color = MUTED)
    cloud = d.get("cloud_connected")
    txt(c, "CLOUD DATA FRESH" if cloud == True else "CLOUD DISCONNECTED" if cloud == False else "CLOUD STATUS UNKNOWN", 15, 24, 167)

# Explicit demo selection only: demos never need settings or network access.
def demo(s):
    p = {"name": "Workshop P2S", "model": "P2S", "online": True, "state": "IDLE", "job": "old_job.3mf", "display_job": "TEGAN KNIFE CAT", "progress": 64, "estimated_completion_local": "11:42 PM", "active_filament_color": "#20DAEA", "active_filament_type": "PLA", "active_filament_slot": "A2", "layer": 231, "total_layers": 417}
    q = dict(p)
    q.update({"name": "Workshop X2D", "model": "X2D", "display_job": "DESK RISER", "progress": 31, "estimated_completion_local": "1:07 AM", "active_filament_color": "#F7F232", "active_filament_slot": "A1"})
    data = {"printers": [p, q], "daily_summary": {"completed_prints": 3, "observed_print_minutes": 684}, "diagnostics": {"age_seconds": 14, "cloud_connected": True}}
    if s in ["P2S PRINTING", "BOTH PRINTING", "MULTICOLOR CHANGE", "PRINT STARTED", "LONG JOB", "DARK FILAMENT", "BRIGHT FILAMENT", "PREPARING", "PAUSED + PRINTING", "ERROR + PRINTING", "OFFLINE + PRINTING"]:
        p["state"] = "PRINTING"
    if s in ["X2D PRINTING", "BOTH PRINTING", "PAUSED + PRINTING", "ERROR + PRINTING", "OFFLINE + PRINTING"]:
        q["state"] = "PRINTING"
    if s in ["PAUSED", "ERROR", "OFFLINE", "PREPARING"]:
        p["state"] = s
    if "+ PRINTING" in s:
        p["state"] = s.split(" +")[0]
    if s in ["LAYERS", "MISSING ETA", "EXPIRED EVENT", "LONG DUAL JOBS"]:
        p["state"] = "PRINTING"
    if s == "LAYERS":
        p.update({"active_filament_slot": "", "active_filament_type": ""})
    if s == "MISSING ETA":
        p["estimated_completion_local"] = None
    if s == "EXPIRED EVENT":
        data["event"] = {"type": "PRINT_STARTED", "printer_model": "P2S", "expires_at": "2000-01-01T00:00:00Z"}
    if s == "LONG DUAL JOBS":
        q["state"] = "PRINTING"
        p["display_job"] = "AN EXTREMELY LONG CYAN MULTICOLOR PRINT TITLE"
        q["display_job"] = "ANOTHER EXTREMELY LONG YELLOW MULTICOLOR PRINT TITLE"
    if s == "MULTICOLOR CHANGE":
        p.update({"active_filament_color": "#EB49D5", "active_filament_slot": "A3"})
    if s == "DARK FILAMENT":
        p["active_filament_color"] = "#020108"
    if s == "BRIGHT FILAMENT":
        p["active_filament_color"] = "#FFFFFF"
    if s == "LONG JOB":
        p["display_job"] = "THE EXTREMELY LONG MULTICOLOR ORGANIZER WITH MANY PARTS"
    if s == "PRINT STARTED":
        data["event"] = {"type": "PRINT_STARTED", "printer_model": "P2S", "expires_at": 9999999999}
    if s == "PRINT FINISHED":
        q.update({"state": "FINISHED", "display_job": "TIGHT FILAMENT CLIP", "completed_at_local": "10:18 PM"})
    if s == "COOLING":
        q.update({"temperature_warning": True, "hot_components": ["bed", "nozzle"], "bed_temp": 56, "nozzle_temp": 74})
    if s == "STALE DATA":
        data["stale"] = True
    if s == "IDLE ZERO":
        data["daily_summary"] = {}
    for printer in [p, q]:
        printer["ams_slots"] = [{"slot": "A"+str(i+1), "type": "PLA", "color": ["#F7F232", "#20DAEA", "#EB49D5", "#020108"][i]} for i in range(4)]
    q["ams_slots"].append({"slot": "DY1", "type": "PETG", "color": "#FFFFFF"})
    return data

def fetch(ctx):
    # Keep the main fetch cache in sync with the 300-second manifest refresh.
    resp = http.get(ctx.inputs.get("endpoint", ""), headers = {"x-api-key": ctx.inputs.get("readkey", "")}, ttl_seconds = 300)
    return resp["json"] if resp["status_code"] == 200 else None

def iso_epoch(v):
    # Expiry timestamps may carry UTC or an explicit timezone offset.
    if type(v) != "string" or len(v) < 19:
        return None
    chunks = [v[:4], v[5:7], v[8:10], v[11:13], v[14:16], v[17:19]]
    if not all([x.isdigit() for x in chunks]):
        return None
    year, month, day, hour, minute, second = [int(x) for x in chunks]
    if year < 1970 or year > 2100 or month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59 or second > 59:
        return None
    days = 0
    for y in range(1970, year):
        days += 366 if y % 4 == 0 and (y % 100 != 0 or y % 400 == 0) else 365
    lengths = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    for m in range(month-1):
        days += lengths[m]
    epoch = (days+day-1)*86400 + hour*3600 + minute*60 + second
    tail = v[19:]
    for sign in ["+", "-"]:
        if sign in tail:
            zone = tail.split(sign)[1].split(":")
            if len(zone) != 2 or not all([x.isdigit() for x in zone]):
                return None
            offset = int(zone[0])*3600 + int(zone[1])*60
            epoch += -offset if sign == "+" else offset
    return epoch

def event_printer(data, printers, ctx):
    e = obj(data.get("event"))
    if e.get("type") not in ["PRINT_STARTED", "PRINT_FINISHED"] or e.get("expired") == True or e.get("active") == False:
        return None
    expiry = e.get("expires_at", e.get("expires_at_iso", e.get("expires_at_unix")))
    age = number(e.get("age_seconds"))
    ttl = number(e.get("ttl_seconds"))
    if age != None and ttl != None and age >= ttl:
        return None
    if type(expiry) in ["int", "float"] and expiry <= ctx.now.unix:
        return None
    if type(expiry) == "string":
        epoch = iso_epoch(expiry)
        if epoch != None and epoch <= ctx.now.unix:
            return None
    target = clean(e.get("printer_model", e.get("printer_name", e.get("printer", e.get("printer_id", e.get("model", ""))))))
    for p in printers:
        if target in [identity(p), clean(p.get("name")), clean(p.get("id"))]:
            return p
    active = [p for p in printers if state(p) in ["PRINTING", "PREPARING", "FINISHED"]]
    return active[0] if len(active) == 1 else None

def render(c, ctx):
    scenario = ctx.inputs.get("demo", "Live")
    if scenario == "Live":
        endpoint = ctx.inputs.get("endpoint", "")
        readkey = ctx.inputs.get("readkey", "")
        if not endpoint or not readkey:
            message(c, "SETUP REQUIRED", "ADD ENDPOINT + KEY")
            return
        if not endpoint.startswith("https://"):
            message(c, "INVALID ENDPOINT", "HTTPS REQUIRED")
            return
    data = demo(scenario.upper()) if scenario != "Live" else fetch(ctx)
    if type(data) != "dict":
        message(c, "NO PRINTER DATA", "CHECK CONNECTION", "red")
        return
    if data.get("stale") == True:
        message(c, "DATA STALE", "CHECK BRIDGE")
        return
    raw = data.get("printers")
    if type(raw) != "list" or not raw or any([type(p) != "dict" for p in raw]):
        message(c, "NO PRINTER DATA", "CHECK BRIDGE", "red")
        return
    printers = raw[:2]
    mode = ctx.inputs.get("view_mode", ctx.inputs.get("viewmode", "Auto"))
    if mode == "AMS" or scenario == "AMS INVENTORY":
        inventory(c, printers)
    elif mode == "Diagnostics" or scenario == "DIAGNOSTICS":
        diagnostics(c, printers, data)
    else:
        problems = [p for p in printers if state(p) in ["ERROR", "OFFLINE"]]
        busy = [p for p in printers if state(p) in ["PRINTING", "PREPARING", "PAUSED"]]
        finished = [p for p in printers if state(p) == "FINISHED"]
        hot = [p for p in printers if p.get("temperature_warning") == True and state(p) == "IDLE"]
        ep = event_printer(data, printers, ctx)
        if problems:
            others = [p for p in printers if p not in problems and p in busy]
            dual(c, (problems+others)[:2]) if len(problems+others) >= 2 else single(c, problems[0])
        elif any([state(p) == "PAUSED" for p in busy]):
            dual(c, busy) if len(busy) == 2 else single(c, busy[0])
        elif ep != None and obj(data.get("event")).get("type") == "PRINT_FINISHED":
            p = dict(ep)
            p["state"] = "FINISHED"
            event = obj(data.get("event"))
            for key in ["display_job", "completed_at_local", "finished_at_local"]:
                if event.get(key):
                    p[key] = event[key]
            single(c, p)
        elif finished:
            single(c, finished[0])
        elif ep != None and obj(data.get("event")).get("type") == "PRINT_STARTED":
            base(c, accent(ep))
            txt(c, identity(ep), 15, 1, 167)
            txt(c, "NEW PRINT STARTED", 15, 10, 167, "5x7", accent(ep))
            txt(c, job(ep), 15, 24, 167)
        elif len(busy) == 2:
            dual(c, busy)
        elif busy:
            single(c, busy[0])
        elif hot:
            single(c, hot[0])
        else:
            idle(c, printers, data)

def main(c, ctx):
    render(c, ctx)
    scenario = ctx.inputs.get("demo", "Live")
    if scenario != "Live":
        mode = ctx.inputs.get("view_mode", ctx.inputs.get("viewmode", "Auto"))
        if (mode == "AMS" or scenario == "AMS INVENTORY") and scenario != "STALE DATA":
            txt(c, "DEMO", 15, 9, 24, color = MUTED)
        elif mode == "Diagnostics" or scenario == "DIAGNOSTICS":
            txt(c, "DEMO", 160, 24, 22, color = MUTED)
        else:
            txt(c, "DEMO", 101, 1, 22, color = MUTED)


