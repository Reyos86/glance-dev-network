# Clean native pixel sprites; no animation or resampling.
def small_icon(c, kind, x, y, col):
    arts = {
        "mitb": ["....GGGG....", "....G..G....", ".GGGGGGGGGG.", ".GggggggggG.", ".GggGGggggG.", ".GGGGGGGGGG.", ".GggGGggggG.", ".GggggggggG.", ".GGGGGGGGGG."],
        "ladder": [
            "..WW....WW..",
            "..WW....WW..",
            "..WWWWWWWW..",
            "..WWWWWWWW..",
            "..WW....WW..",
            "..WW....WW..",
            "..WWWWWWWW..",
            "..WWWWWWWW..",
            "..WW....WW..",
            "..WW....WW..",
        ],
        "cage": ["WWWWWWWWWWWW", "W.W.W.W.W.WW", "WW.W.W.W.W.W", "W.W.W.W.W.WW", "WW.W.W.W.W.W", "W.W.W.W.W.WW", "WW.W.W.W.W.W", "W.W.W.W.W.WW", "WWWWWWWWWWWW"],
        "tag": [".WWW...WWW.", ".W.W...W.W.", ".WWW...WWW.", "...........", "WWWWW.WWWWW", "W...W.W...W", "W...W.W...W"],
        "triple": [".....W.....", "....WWW....", "...........", "..W.....W..", ".WWW...WWW."],
        "rumble": ["WWWWWWWWWWWW", "W..........W", "WWWWWWWWWWWW", "W..........W", "WWWWWWWWWWWW", "W..........W"],
        "mic": ["...WWW...", "..WWWWW..", "..WWWWW..", "...WWW...", "....W....", "....W....", "....W....", "...WWW..."],
    }
    if kind in arts:
        c.sprite(arts[kind], x, y, legend = {"W": col, "G": "#ECD36B", "g": "#167846"})

