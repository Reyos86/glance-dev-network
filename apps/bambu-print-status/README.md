# Bambu Print Status

Finished 192x32 dual-printer SCROLL dashboard. Content stays inside x=10..181.
Auto is state-driven: there is no printer/frame rotation or animation.

## Setup

Enter the read API key issued for your existing Bambu Cloudflare bridge in
**Bambu status read API key** (`readkey`). This remains an encrypted
`app_input_type: api-key` input. No credential is embedded, displayed, or logged.

The existing transport is unchanged:
`https://bambu-glance-status.nickolbp.workers.dev/status`, authenticated with the
`x-api-key` HTTP header. Refresh and HTTP cache TTL remain 60 seconds.

**View mode** defaults to **Auto**, with **AMS** and **Diagnostics** alternatives.
The manifest key is `viewmode`: GDN rejects underscores as render-descriptor
separators, so the requested `view_mode` cannot work as a deployed input key.
Direct render callers may still pass `view_mode` as an alias.

**Studio demo scenario** defaults to **Live**. Select any named scenario to
preview labeled sample data without a key. A missing/invalid key in Live mode
shows NO PRINTER DATA, never fake live information.

## Automatic presentation

- Both idle: combined READY screen; daily completed prints and bridge-observed
  print duration, or READY FOR YOUR NEXT PRINT when today's totals are zero.
  Old job names are hidden.
- One printing/preparing: full-width job, percentage, local completion clock,
  large progress bar, filament indicator and compact slot/type when it fits.
- Both active, including paused + printing: simultaneous rows with model,
  percentage/state, job, completion clock and independent progress colors.
- Errors/offline: red, above normal activity in priority. A second active
  printer remains visible. Paused uses amber and takes priority over start events.
- Start events: temporary NEW PRINT STARTED takeover. Finish events or FINISHED
  state: positive green completion screen and a full 100% progress bar.
- Idle/finished temperature warnings: only relevant hot bed/nozzle readings.
- Stale: amber DATA STALE / CHECK BRIDGE. Failed or malformed HTTP data:
  NO PRINTER DATA / CHECK KEY or CHECK BRIDGE.

`display_job` is preferred to `job`, with measured truncation. Completion clocks
use `estimated_completion_local`; UTC estimates and remaining minutes are not
substituted. Missing clocks are explicitly unknown. Actual completion timestamps
are shown only when `completed_at_local` or `finished_at_local` is supplied.
Layer context fits in the header when a filament label is absent; job, percentage
and completion time retain priority.

Active filament RGB colors drive the print rail, indicator and fill. Very dark
colors are lifted for LED contrast while preserving hue. Alpha in RGBA strings
is ignored. Invalid/missing colors fall back to the normal state color.

## AMS and diagnostics

AMS shows both printers simultaneously, up to five slots each: A1-A4 and HT1
(DY1 is renamed HT1). Actual color swatches and filament types are shown, with
an underline on the active slot. Remaining percentages are intentionally omitted
because they do not fit this fixed inventory grid without harming readability.

Diagnostics is an explicit allowlist: bridge retrieval status, numeric
`age_seconds`, printer online state, and cloud connectivity. Unknown cloud status
is not claimed fresh. No raw diagnostics object, tokens, credentials, email,
serials, or IP addresses are rendered. Lifetime data is not shown.

## Bridge contract notes

`printers` is a list; this dashboard uses its first two records in bridge order.
The supplied printer fields are consumed directly. AMS slot dictionaries support
`slot`/`id`/`name`, `color`/`filament_color`, `type`/`filament_type`, and `active`.
Daily completed counts accept `completed_prints`, `prints_completed`,
`print_count`, `total_prints`, or `prints`; time is `observed_print_minutes`.

Events match printer model/name/id and accept numeric Unix expiry, ISO expiry
with UTC/offset, or `age_seconds` plus `ttl_seconds`. `expired: true` and
`active: false` suppress takeovers. If expiry is absent, the bridge owns event
lifetime and must remove expired events. An event with no identifiable printer
is used only when exactly one printing/preparing/finished printer is present.

## Verification

Glance MCP `render_app` was used repeatedly to inspect every Studio scenario:
both idle; P2S printing; X2D printing; both printing; multicolor change; print
started; print finished; paused; offline; error; cooling; stale; AMS inventory;
diagnostics; preparing; paused/error/offline plus printing; zero daily totals;
long job; dark filament; bright filament; layers; missing ETA; expired event;
and long dual jobs. Also rendered simulated HTTP failure and an invalid key.

Inspection corrected demo-label interference with AMS identity, completion bar
percentage, and dark-color contrast. Final views retain safe-zone margins,
separate job/percentage/time bands, and explicit truncation.

Run `py -3.14 apps/bambu-print-status/tests/check_behavior.py` for 10 focused
behavioral checks (Python-compatible harness; actual Starlark rendering is
verified by Glance MCP). Full GDN validation and catalog preview generation are
performed using Glance MCP. Authenticated successful live retrieval has not been
verified because no real read key was supplied. The app has not been submitted.
