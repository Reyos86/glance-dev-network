"""Dependency-free behavioral checks. MCP validates/renders the real Starlark.
Run: py -3.14 apps/bambu-print-status/tests/check_behavior.py
This harness executes the Python-compatible subset, adapting only type/elems.
"""
from pathlib import Path
from types import SimpleNamespace
import datetime
import unittest

ROOT = Path(__file__).resolve().parents[1]
ns = {'type': lambda v: {dict:'dict', list:'list', str:'string', int:'int', float:'float', bool:'bool', type(None):'NoneType'}.get(type(v), type(v).__name__)}
exec(compile(ROOT.joinpath('app.star').read_text().replace('.elems()', ''), 'app.star', 'exec'), ns)

class Canvas:
    def __init__(self): self.texts=[]; self.bars=[]
    def fill(self,*a,**kw): pass
    def rect(self,*a,**kw): pass
    def line(self,*a,**kw): pass
    def text_width(self,s,font): return len(s)*(6 if font=='5x7' else 5)
    def text(self,s,*a,**kw): self.texts.append(s)
    def progress_bar(self,*a,**kw): self.bars.append((a,kw))

def render(data, **inputs):
    ns['fetch'] = lambda ctx: data
    ctx = SimpleNamespace(inputs=inputs, now=SimpleNamespace(unix=1800000000))
    c=Canvas(); ns['main'](c,ctx)
    return c

class Behavior(unittest.TestCase):
    def test_idle_hides_old_jobs_and_zero_totals(self):
        data=ns['demo']('IDLE ZERO'); c=render(data)
        self.assertIn('READY FOR YOUR NEXT PRINT',c.texts)
        self.assertFalse(any('CAT' in s or '0 PRINT' in s for s in c.texts))
    def test_dual_problem_retains_other_print(self):
        for scenario in ['BOTH PRINTING','PAUSED + PRINTING','ERROR + PRINTING','OFFLINE + PRINTING']:
            c=render(ns['demo'](scenario))
            self.assertIn('P2S',c.texts); self.assertIn('X2D',c.texts)
            self.assertEqual(len(c.bars),2)
    def test_complete_is_full(self):
        c=render(ns['demo']('PRINT FINISHED'))
        self.assertEqual(c.bars[0][0][4],100)
        self.assertIn('FINISHED 10:18 PM',c.texts)
    def test_expired_event_returns_to_print(self):
        d=ns['demo']('PRINT STARTED'); d['event']['expires_at']=1
        self.assertNotIn('NEW PRINT STARTED',render(d).texts)
        d['event']['expires_at']=9999999999
        self.assertIn('NEW PRINT STARTED',render(d).texts)
    def test_iso_offsets(self):
        for v in ['2026-09-21T23:42:00Z','2026-09-21T23:42:00-04:00','2026-09-21T23:42:00+05:30']:
            self.assertEqual(ns['iso_epoch'](v),int(datetime.datetime.fromisoformat(v).timestamp()))
    def test_stale_and_malformed(self):
        self.assertIn('DATA STALE',render({'stale':True}).texts)
        for data in [None,{},[],{'printers':[]},{'printers':[None]}]:
            self.assertIn('NO PRINTER DATA',render(data).texts)
    def test_privacy_allowlist(self):
        d=ns['demo']('DIAGNOSTICS')
        d['diagnostics'].update({'token':'SENSITIVE','ip':'SENSITIVE','email':'SENSITIVE','serial':'SENSITIVE'})
        self.assertNotIn('SENSITIVE',' '.join(render(d,viewmode='Diagnostics').texts))
    def test_ams_ht_and_active_color(self):
        c=render(ns['demo']('AMS INVENTORY'),viewmode='AMS')
        self.assertIn('HT1',c.texts)
        a=render(ns['demo']('P2S PRINTING')).bars[0][1]['color']
        b=render(ns['demo']('MULTICOLOR CHANGE')).bars[0][1]['color']
        self.assertNotEqual(a,b)
    def test_clock_and_color_unknowns(self):
        self.assertEqual(ns['clock']('2026-09-21T23:42:00-04:00'),'11:42 PM')
        self.assertEqual(ns['clock'](None),'')
        self.assertEqual(ns['safe_color']('bad'),'green')
        self.assertNotEqual(ns['safe_color']('#000000'),'#000000')
    def test_paused_beats_start_event(self):
        d=ns['demo']('PRINT STARTED'); d['printers'][1]['state']='PAUSED'
        c=render(d)
        self.assertNotIn('NEW PRINT STARTED',c.texts)
        self.assertEqual(len(c.bars),2)

if __name__=='__main__': unittest.main()
