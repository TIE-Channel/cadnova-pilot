;; CAD-Nova pilot check (partner side), harness version 13
;;
;; Load it in your licensed EDA session:   load("cadnova_check.il")
;;
;; After the run, the script keeps waiting for run requests from TIE while this
;; session stays open: every minute it asks TIE's relay whether TIE
;; requested a run. On a new request it downloads the latest cadnova_check.il,
;; loads it (which runs the checks below and uploads the report) and tells the
;; relay that the run is done. CadNovaStop() ends the waiting.
;;
;; It always uses the LATEST test kit from github.com/TIE-Channel/cadnova-pilot:
;;   1. Downloads kit.sha256 and kit.tgz and verifies the checksum.
;;   2. Starts a separate batch session in a new folder under ~/cadnova_pilot,
;;      with the kit's own cds.lib. Your session, your libraries and your
;;      cds.lib are never touched. TIE's relay supplies the command that
;;      starts the batch session.
;;   3. The batch run opens every cellview listed in the kit read-only, then
;;      for edit, saves it, and lists what it contains (shapes, instances,
;;      pins, nets), so TIE can compare that with CAD-Nova's own reading.
;;      Kits with TIE's generator script (generate.il) first create small test
;;      libraries inside the round folder (GENERATED.txt names them).
;;   4. Streams the test layouts out with strmout.
;;      The batch session and each strmout run get no input (/dev/null) and at
;;      most 10 minutes; one that runs longer is stopped (killed 30 s later if
;;      it does not end), and the report says so (harness 13).
;;   5. Packs a report and uploads it to TIE (privately; never published),
;;      also when a step failed, so that TIE sees what went wrong.
;;
;; The report holds only: the check results with the list of what each test
;; cell contains, the streamed GDS of TIE's test cells, TIE's test cells as
;; the batch run saved them (with the names and sizes of the files in their
;; folders), the test libraries the generator script created in the round
;; folder, warning/error lines from the batch and strmout logs with your
;; paths removed, the kit checksum, the EDA environment's version and the date.
;; To run without uploading, first set   CadNovaNoUpload = t   in this session.
;; Without internet access, put kit.sha256 and kit.tgz from the latest release
;; into ~/cadnova_pilot; the script uses them and names the report to send to TIE.
;;
;; Needs curl or wget, sha256sum, base64 and tar, and the EDA environment's batch
;; program and strmout on PATH.
;; TIE does not run the EDA vendor's software, so this script is untested on our side.

CadNovaConfig = list(nil
    'kitBase   "https://github.com/TIE-Channel/cadnova-pilot/releases/latest/download"
    'uploadUrl "https://script.google.com/macros/s/AKfycbwkFP_Wj65QmwiPEB3c1d0FYVE89Epm4GBYaKcMKKl-yUGgo5Jsm_12cPusah87htu3vg/exec"     ; empty: the report stays on your machine
    'harness   "13"
    'pollTenths 600                ; ask the relay for run requests every 60 s
    'limitSeconds 600              ; most time for the batch session and each strmout run
    ;; Prefix for system tools started from the EDA session: its library path
    ;; can hold its own SSL libraries, which break the system curl and wget.
    'cleanEnv  "env -u LD_LIBRARY_PATH -u LD_PRELOAD"
)

procedure(CadNovaShell(cmd)
    printf("cadnova: %s\n" cmd)
    sh(cmd))

;; cmd as a shell command with no input that runs at most limitSeconds seconds:
;; then timeout stops it and its child processes, and kills them 30 s later if
;; they are still there; it exits with status 124 (or 137). Without timeout on
;; the system, cmd runs without a limit. Output redirections go after it.
procedure(CadNovaLimited(cmd)
    sprintf(nil "if command -v timeout > /dev/null 2>&1; then timeout -k 30 %d %s; else %s; fi < /dev/null"
            CadNovaConfig->limitSeconds cmd cmd))

;; Prints the first lines of a file (tool error messages) into this session's output.
procedure(CadNovaShowFile(path)
    let((port line n)
        n = 0
        port = infile(path)
        when(port
            while(and(n < 15 gets(line port))
                printf("cadnova:   %s" line)
                n = n + 1)
            close(port))))

;; Downloads url to dest: curl without the EDA environment's library path, curl as is, curl
;; ignoring curl's own proxy settings (a stale ALL_PROXY or ~/.curlrc proxy
;; blocks it while the network itself is open), then wget. Writes dest only on
;; success; on failure shows the tools' errors.
procedure(CadNovaFetch(url dest)
    let((part err env ok)
        part = strcat(dest ".part")
        err = strcat(dest ".err")
        env = CadNovaConfig->cleanEnv
        ok = or(CadNovaShell(sprintf(nil "%s curl -fsSL --retry 2 -o '%s' '%s' 2> '%s'" env part url err))
                CadNovaShell(sprintf(nil "curl -fsSL --retry 2 -o '%s' '%s' 2>> '%s'" part url err))
                CadNovaShell(sprintf(nil "%s curl -q --noproxy '*' -fsSL --retry 2 -o '%s' '%s' 2>> '%s'" env part url err))
                CadNovaShell(sprintf(nil "%s wget -nv -O '%s' '%s' 2>> '%s'" env part url err)))
        if(and(ok CadNovaShell(sprintf(nil "mv -f '%s' '%s'" part dest)))
        then t
        else
            printf("cadnova: download failed: %s\n" url)
            CadNovaShowFile(err)
            nil)))

procedure(CadNovaFirstWord(path)
    let((port line parts)
        port = infile(path)
        when(port
            gets(line port)
            close(port)
            parts = and(line parseString(line))
            car(parts))))

procedure(CadNovaCountFailures(resultsFile)
    let((port line parts fails total)
        fails = 0
        total = 0
        port = infile(resultsFile)
        when(port
            while(gets(line port)
                parts = parseString(line)
                when(and(parts equal(car(parts) "result"))
                    total = total + 1
                    when(equal(nth(5 parts) "fail") fails = fails + 1)))
            close(port))
        list(total fails)))

;; Uploads the report (base64 text) to the relay, which answers "ok <path>".
;; Same fallbacks as CadNovaFetch; stops at the first "ok".
procedure(CadNovaUpload(report sha)
    let((answer env b64 url out err post)
        env = CadNovaConfig->cleanEnv
        b64 = strcat(report ".b64")
        url = sprintf(nil "%s?kit=%s" CadNovaConfig->uploadUrl substring(sha 1 12))
        out = strcat(report ".upload")
        err = strcat(report ".upload.err")
        post = sprintf(nil "--data-binary @'%s' -H 'Content-Type: text/plain' '%s' > '%s'" b64 url out)
        cond(
            (and(boundp('CadNovaNoUpload) CadNovaNoUpload)
                printf("cadnova: upload skipped (CadNovaNoUpload is set). Report: %s\n" report)
                nil)
            (equal(CadNovaConfig->uploadUrl "")
                printf("cadnova: no upload address is configured. Please send %s to TIE.\n" report)
                nil)
            (t
                CadNovaShell(sprintf(nil "%s base64 -w0 '%s' > '%s'" env report b64))
                CadNovaShell(sprintf(nil ": > '%s'" err))
                foreach(cmd list(sprintf(nil "%s curl -sSL %s" env post)
                                 sprintf(nil "curl -sSL %s" post)
                                 sprintf(nil "%s curl -q --noproxy '*' -sSL %s" env post)
                                 sprintf(nil "%s wget -nv -O '%s' --post-file='%s' --header='Content-Type: text/plain' '%s'"
                                         env out b64 url))
                    unless(equal(answer "ok")
                        CadNovaShell(sprintf(nil "%s 2>> '%s'" cmd err))
                        answer = CadNovaFirstWord(out)))
                if(equal(answer "ok")
                then
                    printf("cadnova: report uploaded to TIE. Thank you!\n")
                    t
                else
                    printf("cadnova: upload failed. Please send %s to TIE.\n" report)
                    CadNovaShowFile(out)
                    CadNovaShowFile(err)
                    nil)))))

procedure(CadNovaCheck()
    prog((root sumFile handKit online sha work kit kitDir port meta line parts lib cell view report counts
          listing saved dir rel command)
        root = strcat(getShellEnvVar("HOME") "/cadnova_pilot")
        unless(CadNovaShell(sprintf(nil "mkdir -p '%s'" root))
            printf("cadnova: cannot create %s\n" root)
            return(nil))

        ;; 1. Latest kit: checksum first, then the kit itself. Without internet
        ;; access, kit.sha256 and kit.tgz placed in the root folder by hand are used.
        sumFile = strcat(root "/kit.sha256")
        handKit = strcat(root "/kit.tgz")
        online = CadNovaFetch(strcat(CadNovaConfig->kitBase "/kit.sha256") sumFile)
        unless(or(online and(isFile(sumFile) isFile(handKit)))
            printf("cadnova: cannot reach %s.\n" CadNovaConfig->kitBase)
            printf("cadnova: If this machine uses a web proxy, set https_proxy in the shell before starting the EDA session.\n")
            printf("cadnova: Without internet access: download kit.sha256 and kit.tgz from\n")
            printf("cadnova:   https://github.com/TIE-Channel/cadnova-pilot/releases/latest\n")
            printf("cadnova: into %s, then load this script again.\n" root)
            return(nil))
        unless(online
            printf("cadnova: no internet access; using kit.sha256 and kit.tgz from %s\n" root))
        sha = CadNovaFirstWord(sumFile)
        unless(and(sha equal(strlen(sha) 64))
            printf("cadnova: unexpected checksum file\n")
            return(nil))
        work = sprintf(nil "%s/round-%s-%d" root substring(sha 1 12) random(1000000))
        kit = strcat(work "/kit.tgz")
        unless(CadNovaShell(sprintf(nil "mkdir -p '%s'" work))
            printf("cadnova: cannot create %s\n" work)
            return(nil))
        unless(if(online
                  CadNovaFetch(strcat(CadNovaConfig->kitBase "/kit.tgz") kit)
                  CadNovaShell(sprintf(nil "cp '%s' '%s'" handKit kit)))
            printf("cadnova: cannot get the kit\n")
            return(nil))
        unless(CadNovaShell(sprintf(nil "echo '%s  %s' | %s sha256sum -c --status" sha kit CadNovaConfig->cleanEnv))
            printf("cadnova: checksum mismatch. The kit was not used.\n")
            return(nil))
        unless(CadNovaShell(sprintf(nil "%s tar -xzf '%s' -C '%s'" CadNovaConfig->cleanEnv kit work))
            printf("cadnova: cannot unpack the kit\n")
            return(nil))
        kitDir = strcat(work "/kit")

        ;; 2-3. A batch session with the kit's own cds.lib; this session waits until
        ;; it ends. The relay holds the command that starts it.
        command = CadNovaBatchCommand()
        if(command
        then
            printf("cadnova: running the checks in a batch session; this takes a few minutes (at most %d).\n"
                   CadNovaConfig->limitSeconds / 60)
            CadNovaShell(sprintf(nil "cd '%s' && %s > batch.stdout 2>&1; s=$?; if [ $s -eq 124 ] || [ $s -eq 137 ]; then echo 'error: the batch session was stopped after %d minutes (time limit)' | tee -a batch.stdout > batch.limit; if [ -f results.txt ]; then echo 'aborted the batch session was stopped after %d minutes (time limit)' >> results.txt; fi; fi"
                                 kitDir CadNovaLimited(command) CadNovaConfig->limitSeconds / 60 CadNovaConfig->limitSeconds / 60))
            when(isFile(strcat(kitDir "/batch.limit"))
                printf("cadnova: the batch session took longer than %d minutes and was stopped.\n"
                       CadNovaConfig->limitSeconds / 60))
        else
            printf("cadnova: the relay sent no batch command, so the checks cannot run.\n")
            CadNovaShell(sprintf(nil "echo 'error: the relay sent no batch command' > '%s/batch.stdout'" kitDir)))
        CadNovaShell(sprintf(nil "mkdir -p '%s/out'" kitDir))
        if(!isFile(strcat(kitDir "/results.txt"))
        then
            printf("cadnova: the batch run wrote no results (see %s/batch.log). Reporting the failure.\n" kitDir)
        else
            ;; 4. Stream out to GDS every cellview whose manifest line names a layer map.
            port = infile(strcat(kitDir "/MANIFEST.txt"))
            while(and(port gets(line port))
                parts = parseString(line)
                when(and(length(parts) >= 4 !equal(substring(car(parts) 1 1) "#"))
                    lib = nth(0 parts)
                    cell = nth(1 parts)
                    view = nth(2 parts)
                    CadNovaShell(sprintf(nil "cd '%s' && %s > out/%s.strmout.stdout 2>&1"
                                         kitDir
                                         CadNovaLimited(sprintf(nil "strmout -library %s -strmFile out/%s.gds -topCell %s -view %s -layerMap %s -logFile out/%s.strmout.log"
                                                                lib cell cell view nth(3 parts) cell))
                                         cell))
                    unless(isFile(sprintf(nil "%s/out/%s.gds" kitDir cell))
                        printf("cadnova: strmout produced no GDS for %s/%s/%s\n" lib cell view))))
            when(port close(port)))

        ;; 5. Report: metadata, results, warnings without local paths, streamed GDS,
        ;; and the test cellviews as the batch run saved them, for TIE's re-read
        ;; test. saved.txt lists the names and sizes of all files in their view
        ;; folders (a backup copy there shows that saving rewrote a file).
        ;; It is packed and uploaded even when steps failed, so TIE sees the failure.
        ;; Guarded: if listing them fails, the report still goes, without them.
        saved = nil
        listing = nil
        port = nil
        unless(car(errset(
                progn(
                    listing = outfile(strcat(kitDir "/saved.txt") "w")
                    port = infile(strcat(kitDir "/MANIFEST.txt"))
                    while(and(port listing gets(line port))
                        parts = parseString(line)
                        when(and(length(parts) >= 3 !equal(substring(car(parts) 1 1) "#"))
                            dir = sprintf(nil "libs/%s/%s/%s" nth(0 parts) nth(1 parts) nth(2 parts))
                            when(isDir(strcat(kitDir "/" dir))
                                foreach(name sort(getDirFiles(strcat(kitDir "/" dir)) 'alphalessp)
                                    rel = strcat(dir "/" name)
                                    when(isFile(strcat(kitDir "/" rel))
                                        fprintf(listing "file %s %d\n" rel fileLength(strcat(kitDir "/" rel)))
                                        when(rexMatchp("\\.oa$" name)
                                            saved = cons(sprintf(nil "'%s'" rel) saved)))))))
                    t)
                t))
            saved = nil
            printf("cadnova: could not list the saved cellviews; the report is sent without them.\n"))
        when(port close(port))
        when(listing close(listing))
        ;; Libraries TIE's generator script created in the batch run (GENERATED.txt,
        ;; harness 9): returned whole, their technology databases included.
        port = infile(strcat(kitDir "/GENERATED.txt"))
        while(and(port gets(line port))
            parts = parseString(line)
            when(and(parts isDir(sprintf(nil "%s/libs/%s" kitDir car(parts))))
                saved = cons(sprintf(nil "'libs/%s'" car(parts)) saved)))
        when(port close(port))
        meta = outfile(strcat(kitDir "/meta.txt") "w")
        fprintf(meta "harness %s\nkit %s\n" CadNovaConfig->harness sha)
        close(meta)
        CadNovaShell(sprintf(nil "cd '%s' && date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ >> meta.txt" kitDir))
        ;; At most 500 lines from each log, 500 in all (harness 13).
        CadNovaShell(sprintf(nil "cd '%s' && (grep -m 500 -E '\\*(WARNING|Error)\\*' batch.log; grep -m 500 -hiE 'error|warning' batch.stdout out/*.strmout.log out/*.strmout.stdout) 2>/dev/null | head -n 500 | sed 's#%s#<work>#g; s#%s#<home>#g' > warnings.txt"
                             kitDir work getShellEnvVar("HOME")))
        report = strcat(work "/cadnova_report.tgz")
        unless(CadNovaShell(sprintf(nil "cd '%s' && %s tar -czf '%s' meta.txt warnings.txt $(ls results.txt saved.txt out/*.gds 2>/dev/null) %s"
                                    kitDir CadNovaConfig->cleanEnv report buildString(reverse(saved) " ")))
            printf("cadnova: cannot pack the report\n")
            return(nil))
        counts = CadNovaCountFailures(strcat(kitDir "/results.txt"))
        if(zerop(car(counts))
            printf("\ncadnova: no checks ran.\n")
            printf("\ncadnova: %d checks, %d failed.\n" car(counts) cadr(counts)))
        CadNovaUpload(report sha)
        return(t)))

;; ---------------------------------------------------------------- run requests from TIE

;; Kept across reloads of this script: the polling state.
unless(boundp('CadNovaListening) CadNovaListening = nil)
unless(boundp('CadNovaSeen) CadNovaSeen = nil)       ; last run id seen at the relay
unless(boundp('CadNovaRun) CadNovaRun = nil)         ; run id being handled

;; Asks the relay (GET ?<query>) without printing; returns the answer's first word.
procedure(CadNovaAsk(query)
    let((out env url)
        out = strcat(getShellEnvVar("HOME") "/cadnova_pilot/relay.answer")
        env = CadNovaConfig->cleanEnv
        url = sprintf(nil "%s?%s" CadNovaConfig->uploadUrl query)
        sh(sprintf(nil "mkdir -p '%s/cadnova_pilot' && : > '%s'" getShellEnvVar("HOME") out))
        foreach(cmd list(sprintf(nil "%s curl -fsSL -o '%s' '%s'" env out url)
                         sprintf(nil "curl -fsSL -o '%s' '%s'" out url)
                         sprintf(nil "%s curl -q --noproxy '*' -fsSL -o '%s' '%s'" env out url)
                         sprintf(nil "%s wget -q -O '%s' '%s'" env out url))
            unless(CadNovaFirstWord(out)
                sh(sprintf(nil "%s 2>/dev/null" cmd))))
        CadNovaFirstWord(out)))

;; The first line of a file without its line end; nil when there is none.
procedure(CadNovaFirstLine(path)
    let((port line)
        port = infile(path)
        when(port
            gets(line port)
            close(port)
            and(line car(parseString(line "\n"))))))

;; The whole command that starts the batch session in the kit folder, with
;; run_checks.il and the batch.log log file (harness 12; CadNovaLimited wraps
;; it since harness 13). The relay holds it in
;; its BATCH_COMMAND property and answers "command <the command>". Only
;; letters, digits, spaces and _ . / + - are accepted, so it cannot carry other
;; shell commands. nil without an answer.
procedure(CadNovaBatchCommand()
    let((line)
        when(equal(CadNovaAsk("action=command") "command")
            line = CadNovaFirstLine(strcat(getShellEnvVar("HOME") "/cadnova_pilot/relay.answer"))
            line = and(line strlen(line) > 8 substring(line 9))
            when(and(line rexMatchp("^[A-Za-z0-9_./][A-Za-z0-9_./+ -]*$" line))
                line))))

;; Tells the relay that the requested run is done (nothing when no run was requested).
procedure(CadNovaDone()
    when(CadNovaRun
        CadNovaAsk(sprintf(nil "action=done&id=%s" CadNovaRun))
        printf("cadnova: run %s done; TIE has been told.\n" CadNovaRun)
        CadNovaRun = nil))

;; Called every minute by a timer: on a new run request, download the latest
;; script and load it; loading runs the checks and reports the run done.
procedure(CadNovaPoll()
    let((run script)
        when(CadNovaListening
            run = CadNovaAsk("action=poll")
            when(and(run !equal(run "none") !equal(run CadNovaSeen))
                CadNovaSeen = run
                CadNovaRun = run
                printf("cadnova: TIE requested run %s\n" run)
                script = strcat(getShellEnvVar("HOME") "/cadnova_pilot/cadnova_check.il")
                if(CadNovaFetch(strcat(CadNovaConfig->kitBase "/cadnova_check.il") script)
                    errset(load(script) t)
                    errset(CadNovaCheck() t))
                CadNovaDone())
            hiRegTimer("CadNovaPoll()" CadNovaConfig->pollTenths))))

;; Starts waiting for run requests (once per session); earlier requests are not run.
procedure(CadNovaListen()
    unless(or(CadNovaListening equal(CadNovaConfig->uploadUrl ""))
        CadNovaSeen = CadNovaAsk("action=poll")
        CadNovaListening = t
        printf("cadnova: waiting for run requests from TIE while this session is open. CadNovaStop() ends this.\n")
        hiRegTimer("CadNovaPoll()" CadNovaConfig->pollTenths)))

procedure(CadNovaStop()
    CadNovaListening = nil
    printf("cadnova: no longer waiting for run requests from TIE.\n"))

CadNovaCheck()
CadNovaDone()
CadNovaListen()
