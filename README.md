# CAD-Nova pilot

Test kits for checking that files written by **CAD-Nova**, the chip-layout
tool from [TIE-Games](https://tie-games.com), open cleanly in a commercial EDA
environment for IC design. Pilot partners with their own EDA license run one
script; it checks the latest test kit and sends the report to TIE.

## Run it

1. Download [`cadnova_check.il`](https://github.com/TIE-Channel/cadnova-pilot/releases/latest/download/cadnova_check.il).
   It always fetches the latest test kit. Download it again only when TIE
   announces a new version of the script itself (now version 13).
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
   The batch session gets no input and at most 10 minutes; if it takes
   longer, the script stops it (and kills it 30 s later if needed) and
   reports that.
3. TIE's generator script (`generate.il`) first creates small test libraries
   in that folder, from content TIE wrote. Then, for each test cell: opens it
   read-only and lists its shapes, instances, pins and nets; then opens it for
   edit, saves it and closes it. TIE compares that list with what CAD-Nova
   reads from the same files, and reads the files as the batch session saved
   them.
4. Streams the sky130 test layouts out with `strmout` (each run also with
   no input and at most 10 minutes).
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

## Rounds

Each round is a release; the script always uses the newest one.

| Round | Content |
|---|---|
| `round-27` | Version 12 of the script: TIE's relay supplies the command that starts the batch session. The kit holds public sky130, FreePDK3, ASAP7 and Aureo cells exactly as published, and TIE's generator script, which creates four small test libraries (`cadnova_tech`, `cadnova_test`, `cadnova_vias`, `cadnova_init`) inside the round folder. Nothing outside the round folder is touched. |
| `round-28` | As `round-27`; only a comment in the kit's `run_checks.il` changed. Same script (version 12). |
| `round-29` | Version 8 of the generator script: four more small technology libraries inside the round folder (`cadnova_antenna`, `cadnova_antenna2`, `cadnova_antenna3`, `cadnova_density`), each built from a techfile TIE wrote, with antenna and density rules whose values all differ. Same script (version 12). |
| `round-30` | Version 9 of the generator script: one more small technology library, `cadnova_display`, with display settings that differ per layer and a few layer properties. Same script (version 12). |
| `round-31` | Version 10 of the generator script: two more small technology libraries, `cadnova_mpp` (a multipart path template and electrical rules whose values all differ) and `cadnova_stamp` (stamp-label layers). Same script (version 12). |
| `round-32` | Version 11 of the generator script: `cadnova_elec` (electrical rules) replaces `cadnova_mpp`, whose template your batch session cannot load; `cadnova_stamp` gets its label layers and one more entry. Same script (version 12). |
| `round-33` | Six public cellviews with property values changed by CAD-Nova (strings, numbers, a time, a boolean and a list value on cellviews, instances and shapes; see `EDITS.txt`). The batch run also lists every property of each kit cellview. Same script (version 12) and generator (version 11). |
| `round-34` | Four public cellviews with PCell parameter values changed by CAD-Nova (two variants' parameters, two formal parameters; see `EDITS.txt`). Same script (version 12) and generator (version 11). |
| `round-35` | Four public cellviews with properties added and deleted by CAD-Nova (on cellviews, instances and shapes; see `EDITS.txt`). Same script (version 12) and generator (version 11). |
| `round-36` | Three public cellviews with property groups, ranges and an enum added by CAD-Nova, and one group deleted (see `EDITS.txt`). Same script (version 12) and generator (version 11). |
| `round-37` | Four public cellviews with properties renamed, given other types, and one cellview's last property deleted by CAD-Nova (see `EDITS.txt`). Version 12 of the generator script: in its small `props` test view, one enum property is made and deleted again, and one property's type is changed. Same script (version 12). |
| `round-38` | Three public cellviews without properties get some from CAD-Nova (among them a streamed sky130 cell), and one gets two enum properties, one deleted again (see `EDITS.txt`). Same script (version 12) and generator (version 12). |
| `round-39` | No edits. Two more public Aureo cellviews, and the batch run also lists the properties of groups, markers and other objects of each cellview. Same script (version 12) and generator (version 12). |
| `round-40` | Four public cellviews with properties added by CAD-Nova to groups, group members, routes, a marker, a schematic's block and an instance header, and one route's property deleted (see `EDITS.txt`). The batch run also lists group members' properties. Same script (version 12) and generator (version 12). |
| `round-41` | Two public FreePDK3 layouts with pin labels deleted by CAD-Nova, and one pin label copied (see `EDITS.txt`). Same script (version 12) and generator (version 12). |
| `round-42` | No edits. Version 13 of the generator script: one more small test view, `cadnova_test/pins`, with four pins; your batch session deletes one pin's only figure, one pin, and one of another pin's two figures, then saves it. Same script (version 12). |
| `round-43` | Three public Aureo layouts with pins deleted by CAD-Nova (their shapes stay) and pins' only shapes deleted (the pins stay); see `EDITS.txt`. Version 14 of the generator script: in `cadnova_test/pins`, pins with two and three shapes lose one, one of a terminal's three pins is deleted, and one label keeps a shape as its parent. Same script (version 12). |
| `round-44` | Two public FreePDK3 layouts with pin shapes deleted by CAD-Nova together with their labels, and one pin label copied; one more public Aureo layout, `scumv24_footprint`, whose pins have up to 40 shapes, with one shape of two pins deleted (see `EDITS.txt`). Version 15 of the generator script: in `cadnova_test/pins`, three more labels get a parent shape, and three parent shapes are deleted. Same script (version 12). |
| `round-45` | Three public FreePDK3 layouts: two with a pin shape deleted by CAD-Nova together with its label, one with a pin deleted whose shape keeps its label (see `EDITS.txt`). Version 16 of the generator script: in `cadnova_test/pins`, one more pin with a labelled shape is deleted, and one label whose parent is a pin shape is deleted. Same script (version 12). |
| `round-46` | Three public layouts (FreePDK3 `nor`, Aureo `cap_vmam` and `scm3c_footprint`) with a terminal added by CAD-Nova, with its net, pin and pin shape (see `EDITS.txt`). Version 17 of the generator script: in `cadnova_test/pins`, one terminal and its net are deleted and another one is made. Same script (version 12). |
| `round-47` | Four public layouts: two with a terminal deleted by CAD-Nova (one with its net), two with a pin added to an existing terminal (see `EDITS.txt`). Version 18 of the generator script: in `cadnova_test/pins`, a terminal is deleted, a net is deleted while it has a terminal, and a terminal gets one more pin. Same script (version 12). |
| `round-48` | Two public FreePDK3 layouts with a net deleted by CAD-Nova together with its terminal and pin (see `EDITS.txt`). Version 19 of the generator script: one more small test view, `cadnova_test/font`, with labels of every printable character in three fonts, a few words, and one text in every size, justification and orientation tested. Same script (version 12). |
| `round-49` | Two public FreePDK3 layouts with a pin added by CAD-Nova together with its label (see `EDITS.txt`). Same script (version 12) and generator (version 19). |
| `round-50` | Five public layouts: labels renamed or copied by CAD-Nova with recomputed boxes (FreePDK3 `nor` and `xor_double`, sky130 `inv_1`), and rectangles added on nets (FreePDK3 `nand`, Aureo `cap_vmam`); see `EDITS.txt`. Version 20 of the generator script: in `cadnova_test/pins`, one rectangle is added to a net. Same script (version 12). |
| `round-51` | No edits. Version 21 of the generator script: two more small test views, `cadnova_test/conn` and `cadnova_test/conndel`, with instances whose terminals your batch session connects to nets (in `conndel` it then deletes two of the connections). Same script (version 12). |
| `round-52` | Two public Aureo layouts with instance terminals deleted by CAD-Nova, and one moved to another net (see `EDITS.txt`). Same script (version 12) and generator (version 21). |
| `round-53` | Three public Aureo layouts with instance terminals added, deleted and moved by CAD-Nova; one more, `vertical_relay`, in the kit (see `EDITS.txt`). Version 22 of the generator script: one more small test view, `cadnova_test/connmid`, where your batch session deletes one connection and makes another. Same script (version 12). |
| `round-54` | As `round-53`, with a correction in one CAD-Nova file (`vertical_relay`), which stopped the batch session in `round-53`. Version 23 of the generator script corrects one step of `cadnova_test/connmid`. Same script (version 12). |
| `round-55` | Three public Aureo layouts with instance terminals disconnected by CAD-Nova (and one connected again) whose terminals' places in the master's terminal list stay, empty or taken again (see `EDITS.txt`). Same script (version 12) and generator (version 23). |
| `round-56` | No edits. Version 24 of the generator script: one more small test view, `cadnova_test/instdel`, where your batch session deletes two connected instances. Same script (version 12). |
| `round-57` | Four public layouts with instances deleted by CAD-Nova (one with its connection, one the last of its master), and one instance added again (see `EDITS.txt`). Same script (version 12) and generator (version 24). |
| `round-58` | Six public layouts with polygons, lines, paths, donuts, ellipses, dots and arcs added by CAD-Nova, two of them streamed out (see `EDITS.txt`). Version 25 of the generator script: one more small test view, `cadnova_test/shapes`, with round-ended paths, sharp corners, arcs and deleted shapes. Same script (version 12). |
| `round-59` | Six public layouts: curves and round-ended paths added by CAD-Nova (two streamed out), and polygons, lines and paths reshaped (see `EDITS.txt`). Version 26 of the generator script: one more small test view, `cadnova_test/reshape`, with shapes your batch session reshapes and paths with sharp corners. Same script (version 12). |
| `round-60` | Five public layouts with polygons, lines and paths reshaped by CAD-Nova, one streamed out (see `EDITS.txt`). Version 27 of the generator script: three more small test views, `cadnova_test/acute` (paths turned into polygons), `font2` (labels in the other fonts) and `viadel` (vias deleted and added). Same script (version 12). |
| `round-61` | Three public layouts with vias added (and some deleted again) by CAD-Nova, two with labels in other fonts, one of those streamed out (see `EDITS.txt`). Version 28 of the generator script: one more small test view, `cadnova_test/viadel2`, where your batch session deletes the only via of a kind. Same script (version 12). |
| `round-62` | Three public layouts with bus terminals and nets (and a lone bit) added by CAD-Nova (see `EDITS.txt`). Same script (version 12) and generator (version 28). |
| `round-63` | Two public layouts with bus terminals and nets added by CAD-Nova, one of them round 62's again with a fix (see `EDITS.txt`). Same script (version 12) and generator (version 28). |
| `round-64` | No edits. Version 29 of the generator script: as its last step, your batch session copies `aureo_lib/vertical_relay` twice into `cadnova_test`, saves one copy as it is and adds three buses to the other before saving it. Same script (version 12). |
| `round-65` | No edits. Version 30 of the generator script: version 29's copy step returned nothing, so your batch session now opens `aureo_lib/vertical_relay`, saves it under two new names in `cadnova_test` (the second after adding three buses) and discards the changes to the original. Same script (version 12). |
| `round-66` | No edits. Version 31 of the generator script: version 30's saves under new names returned nothing (the target library has another technology), so your batch session now makes a library `cadnova_aureo` bound to `aureo_lib`'s technology and copies or saves `aureo_lib/vertical_relay` there (once after adding three buses). Same script (version 12). |
| `round-67` | Two public layouts with bus terminals and nets added by CAD-Nova (see `EDITS.txt`). Version 32 of the generator script: two more copies of `aureo_lib/vertical_relay` in `cadnova_aureo`, one with a terminal and net added, one with one bus. Same script (version 12). |
| `round-68` | Two public schematics with wires, nets and instance connections changed by CAD-Nova (see `EDITS.txt`). Same script (version 12) and generator (version 32). |
| `round-69` | Two public schematics with pins (pin-symbol instances with terminals and nets) added by CAD-Nova (see `EDITS.txt`). Same script (version 12) and generator (version 32). |
| `round-70` | No edits: round 69's batch session hung, so this kit leaves its schematic edits out. Same script (version 12) and generator (version 32). |
| `round-71` | No edits. Script version 13: the batch session and each `strmout` run get no input and at most 10 minutes; a run that takes longer is stopped (and killed 30 s later if needed), and the report says so. Generator version 32. |
| `round-72` | Round 69's two schematics with pins added by CAD-Nova, again (see `EDITS.txt`), now with script version 13's time limit; the kit's batch script writes each result line out at once. Same script (version 13) and generator (version 32). |
| `round-73` | No edits. Version 33 of the generator script: your batch session saves copies of the kit's FreePDK3 `nand` and `d_latch` schematics in a new library `cadnova_sch` inside the round folder, as they are and after adding pins with the EDA environment's own functions. Same script (version 13). |
| `round-74` | Round 69's two schematics with pins added by CAD-Nova, written as your EDA environment wrote its own pins in round 73 (see `EDITS.txt`). Same script (version 13) and generator (version 33). |
| `round-75` | Round 69's two schematics with pins added by CAD-Nova, now also with a layout detail fixed that kept round 74's `d_latch` from opening (see `EDITS.txt`). Version 34 of the generator script: the copies in `cadnova_sch` are no longer made. Same script (version 13). |
| `round-76` | No edits. Version 35 of the generator script: four more small layouts in `cadnova_test` with path segments and routes made by the EDA environment's own functions, then some deleted or moved. Same script (version 13). |
| `round-77` | Four public layouts with routes and path segments deleted or moved by CAD-Nova (see `EDITS.txt`). Same script (version 13) and generator (version 35). |
| `round-78` | Four public layouts with routes and path segments added by CAD-Nova (see `EDITS.txt`). Version 36 of the generator script: two more small layouts in `cadnova_test` with routes and segments added by the EDA environment's own functions. Same script (version 13). |
| `round-79` | No edits. Version 37 of the generator script: two more small layouts in `cadnova_test`, one with an instance of `leaf`, one with instances of three more cells added by the EDA environment's own functions. Same script (version 13). |
| `round-80` | Three public layouts with instances of cells they did not place before, added by CAD-Nova (see `EDITS.txt`). Same script (version 13) and generator (version 37). |

## Licenses

- Kit contents are public, permissively licensed files. Their licenses are
  inside each kit, in `LICENSES/`.
- The scripts are provided by TIE-Games for running the CAD-Nova pilot.
