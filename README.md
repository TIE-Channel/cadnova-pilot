# CAD-Nova pilot

Test kits for checking that files written by **CAD-Nova**, the chip-layout
tool from [TIE-Games](https://tie-games.com), open cleanly in a commercial EDA
environment for IC design. Pilot partners with their own EDA license run one
script; it checks the latest test kit and sends the report to TIE.

## Run it

1. Download [`cadnova_check.il`](https://github.com/TIE-Channel/cadnova-pilot/releases/latest/download/cadnova_check.il).
   It always fetches the latest test kit. Download it again only when TIE
   announces a new version of the script itself (now version 12).
2. In your licensed EDA session, run:
   ```
   load("cadnova_check.il")
   ```

That's all. The session shows the progress and a summary at the end. It is
busy for the few minutes the checks run.

## What the script does

All work happens in a new folder under `~/cadnova_pilot`.

1. Downloads the latest `kit.sha256` and `kit.tgz` from this repository's
   releases and verifies the checksum.
2. Starts a separate batch session in that folder, using only the kit's own
   `cds.lib`. Your session, your libraries and your `cds.lib` are never
   touched. TIE's relay supplies the command that starts the batch session;
   the script accepts only letters, digits, spaces and `_ . / + -` in it.
3. TIE's generator script (`generate.il`) first creates small test libraries
   in that folder, from content TIE wrote. Then, for each test cell: opens it
   read-only and lists its shapes, instances, pins and nets; then opens it for
   edit, saves it and closes it. TIE compares that list with what CAD-Nova
   reads from the same files, and reads the files as the batch session saved
   them.
4. Streams the sky130 test layouts out with `strmout`.
5. Packs `cadnova_report.tgz` and uploads it to TIE, also when a step
   failed, so TIE can see what went wrong. It goes to a private store and is
   never published.
6. Keeps waiting for run requests from TIE while this session is open. Every
   minute it asks TIE's relay; when TIE requests a run, it downloads the
   latest script, runs it (steps 1–5) and tells the relay the run is done. The
   session is busy while a run takes place. To stop waiting, run
   `CadNovaStop()` in the session, or close it.

**What the report contains:**
- the check results and the list of what each test cell contains;
- the streamed GDS of TIE's test cells;
- TIE's test cells as the batch run saved them, with the names and sizes of
  the files in their folders, so TIE can check that CAD-Nova reads what the
  batch session saved;
- the test libraries the generator script created in the round folder;
- warning and error lines from the batch and `strmout` logs, with your paths
  removed;
- the kit checksum, the EDA version and the date.

To keep the report on your machine instead, run `CadNovaNoUpload = t` in the
session before loading the script.

**Requirements:** Linux, your EDA environment with its batch mode and
`strmout`, and `curl`, `sha256sum`, `base64` and `tar` on PATH. The batch run
uses one extra EDA license for the few minutes it runs. Before the first run,
please confirm that your EDA license permits running these scripts.

## Current round

Each round is a release; the script always uses the newest one.

| Round | Content |
|---|---|
| `round-27` | Version 12 of the script: TIE's relay supplies the command that starts the batch session. The kit holds public sky130, FreePDK3, ASAP7 and Aureo cells exactly as published, and TIE's generator script, which creates four small test libraries (`cadnova_tech`, `cadnova_test`, `cadnova_vias`, `cadnova_init`) inside the round folder. Nothing outside the round folder is touched. |

## Licenses

- Kit contents are public, permissively licensed files. Their licenses are
  inside each kit, in `LICENSES/`.
- The scripts are provided by TIE-Games for running the CAD-Nova pilot.
