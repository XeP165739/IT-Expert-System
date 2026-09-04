;; ============================================================
;;  IT SUPPORT EXPERT SYSTEM - CLIPS LOGIC LAYER
;; ============================================================
;;  This file owns ALL decision logic from the troubleshooting
;;  flowchart / rule table (Steps 1-6, categories A-I, R1-R13).
;;  It does NOT talk to the user directly - the Python driver
;;  (it_support_expert_system.py) collects answers, asserts them
;;  as facts, calls (run), then reads back the resulting
;;  action-log / diagnosis / escalation / ticket facts.
;; ============================================================


;; ----------------------------------------------------------
;; DEFTEMPLATES (the "data model" of the expert system)
;; ----------------------------------------------------------

(deftemplate case-info
   (slot user-name (type STRING) (default "unknown"))
   (slot device-id (type STRING) (default "unknown"))
   (slot location (type STRING) (default "unknown"))
   (slot problem-desc (type STRING) (default ""))
   (slot start-time (type STRING) (default ""))
   (slot error-message (type STRING) (default "none"))
   (slot activity (type STRING) (default ""))
   (slot prior-attempts (type STRING) (default "none"))
   (slot other-users-affected (type SYMBOL) (allowed-symbols yes no) (default no)))

(deftemplate critical-flags
   (slot security-incident (type SYMBOL) (allowed-symbols yes no) (default no))
   (slot data-loss (type SYMBOL) (allowed-symbols yes no) (default no))
   (slot critical-system-down (type SYMBOL) (allowed-symbols yes no) (default no)))

(deftemplate category
   (slot code (type SYMBOL) (allowed-symbols A B C D E F G H I)))

;; Generic fact used to hold every category-specific yes/no answer.
;; Using one generic template (rather than one slot per question)
;; keeps the schema open-ended, the way a real intake form is.
(deftemplate answer
   (slot topic (type SYMBOL))
   (slot value (type SYMBOL) (allowed-symbols yes no some none)))

;; Audit trail of every action the engine decided to take/recommend.
(deftemplate action-log
   (slot step (type INTEGER))
   (slot action (type STRING)))

(deftemplate diagnosis
   (slot root-cause (type STRING) (default "undetermined"))
   (slot resolved (type SYMBOL) (allowed-symbols yes no) (default no)))

(deftemplate escalation
   (slot target (type STRING))
   (slot reason (type STRING))
   (slot priority (type SYMBOL) (allowed-symbols CRITICAL HIGH MEDIUM LOW) (default MEDIUM)))

(deftemplate ticket
   (slot status (type SYMBOL) (allowed-symbols OPEN CLOSED ESCALATED) (default OPEN))
   (slot priority (type SYMBOL) (allowed-symbols CRITICAL HIGH MEDIUM LOW) (default LOW))
   (slot root-cause (type STRING) (default ""))
   (slot solution (type STRING) (default "")))


;; ============================================================
;; STEP 2 - CRITICAL CONDITION CHECK   (R6, R7, R8)
;; Highest salience: these must fire before anything else and
;; halt the engine, exactly like the flowchart's "do this first".
;; ============================================================

(defrule critical-security-incident
   (declare (salience 1000))
   (critical-flags (security-incident yes))
   =>
   (assert (action-log (step 2) (action "Security incident suspected - halted normal troubleshooting, isolate device if possible")))
   (assert (escalation (target "Security / Administrator") (reason "Suspected security incident / malware (R6)") (priority CRITICAL)))
   (assert (ticket (status ESCALATED) (priority CRITICAL) (root-cause "Suspected security incident")
                   (solution "Escalated immediately - no automated troubleshooting performed")))
   (halt))

(defrule critical-data-loss
   (declare (salience 999))
   (critical-flags (security-incident no) (data-loss yes))
   =>
   (assert (action-log (step 2) (action "Data loss/corruption suspected - stopped potentially destructive actions")))
   (assert (escalation (target "Appropriate Specialist") (reason "Suspected data loss or corruption (R7)") (priority CRITICAL)))
   (assert (ticket (status ESCALATED) (priority CRITICAL) (root-cause "Suspected data loss or corruption")
                   (solution "Escalated immediately - no automated troubleshooting performed")))
   (halt))

(defrule critical-system-down
   (declare (salience 998))
   (critical-flags (security-incident no) (data-loss no) (critical-system-down yes))
   =>
   (assert (action-log (step 2) (action "Critical business system unavailable")))
   (assert (escalation (target "Appropriate Specialist") (reason "Critical business system unavailable (R8)") (priority CRITICAL)))
   (assert (ticket (status ESCALATED) (priority CRITICAL) (root-cause "Critical system outage")
                   (solution "Escalated immediately - no automated troubleshooting performed")))
   (halt))

(defrule proceed-to-classification
   (declare (salience 997))
   (critical-flags (security-incident no) (data-loss no) (critical-system-down no))
   =>
   (assert (action-log (step 2) (action "No critical conditions detected - proceeding to problem classification"))))


;; ============================================================
;; STEP 3 - CATEGORY LOG   (R1)
;; ============================================================

(defrule log-category
   (declare (salience 200))
   (category (code ?c))
   =>
   (assert (action-log (step 3) (action (str-cat "Problem classified as category " ?c)))))


;; ============================================================
;; CATEGORY A - COMPUTER DOES NOT TURN ON / NO POWER
;; ============================================================

(defrule cat-A-cable-disconnected
   (declare (salience 90))
   (category (code A))
   (answer (topic power-cable-connected) (value no))
   =>
   (assert (action-log (step 3) (action "[A] Power cable disconnected - reconnected securely")))
   (assert (diagnosis (root-cause "Power cable was disconnected") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Power cable disconnected") (solution "Reconnected power cable"))))

(defrule cat-A-outlet-not-working
   (declare (salience 89))
   (category (code A))
   (answer (topic power-cable-connected) (value yes))
   (answer (topic outlet-working) (value no))
   =>
   (assert (action-log (step 3) (action "[A] Outlet/power strip not working - tried known-good outlet/strip")))
   (assert (diagnosis (root-cause "Faulty electrical outlet or power strip") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Faulty outlet/power strip") (solution "Switched to known-good outlet/power strip"))))

(defrule cat-A-adapter-suspect
   (declare (salience 88))
   (category (code A))
   (answer (topic power-cable-connected) (value yes))
   (answer (topic outlet-working) (value yes))
   (answer (topic is-laptop) (value yes))
   (answer (topic adapter-suspect) (value yes))
   =>
   (assert (action-log (step 3) (action "[A] Laptop power adapter suspected - tried known-good compatible adapter")))
   (assert (diagnosis (root-cause "Faulty laptop power adapter") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Faulty power adapter") (solution "Replaced with known-good adapter"))))

(defrule cat-A-no-response
   (declare (salience 87))
   (category (code A))
   (answer (topic power-button-response) (value none))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[A] No response from power button/indicators - suspected internal hardware failure")))
   (assert (diagnosis (root-cause "Suspected internal hardware failure (PSU/motherboard)") (resolved no)))
   (assert (escalation (target "Hardware / Level-2 Technician") (reason "No power response - suspected internal hardware failure") (priority MEDIUM))))

(defrule cat-A-fallback
   (declare (salience 70))
   (category (code A))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[A] Basic power checks did not resolve the issue")))
   (assert (diagnosis (root-cause "Undetermined power issue") (resolved no)))
   (assert (escalation (target "Hardware / Level-2 Technician") (reason "Escalated for hardware diagnosis after basic power checks failed") (priority MEDIUM))))


;; ============================================================
;; CATEGORY B - COMPUTER TURNS ON BUT NO DISPLAY
;; ============================================================

(defrule cat-B-monitor-off
   (declare (salience 90))
   (category (code B))
   (answer (topic monitor-powered-on) (value no))
   =>
   (assert (action-log (step 3) (action "[B] Monitor was powered off - turned monitor on")))
   (assert (diagnosis (root-cause "Monitor was powered off") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Monitor powered off") (solution "Turned monitor on"))))

(defrule cat-B-monitor-cable-loose
   (declare (salience 89))
   (category (code B))
   (answer (topic monitor-powered-on) (value yes))
   (answer (topic monitor-power-cable-loose) (value yes))
   =>
   (assert (action-log (step 3) (action "[B] Monitor power cable loose - reconnected")))
   (assert (diagnosis (root-cause "Loose monitor power cable") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Loose monitor power cable") (solution "Reconnected monitor power cable"))))

(defrule cat-B-video-cable-loose
   (declare (salience 88))
   (category (code B))
   (answer (topic monitor-power-cable-loose) (value no))
   (answer (topic video-cable-loose) (value yes))
   =>
   (assert (action-log (step 3) (action "[B] Video cable loose - reconnected")))
   (assert (diagnosis (root-cause "Loose video cable") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Loose video cable") (solution "Reconnected video cable"))))

(defrule cat-B-wrong-input
   (declare (salience 87))
   (category (code B))
   (answer (topic video-cable-loose) (value no))
   (answer (topic correct-input-selected) (value no))
   =>
   (assert (action-log (step 3) (action "[B] Incorrect monitor input selected - corrected input source")))
   (assert (diagnosis (root-cause "Wrong monitor input/source selected") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Wrong monitor input selected") (solution "Selected correct input source"))))

(defrule cat-B-faulty-cable
   (declare (salience 86))
   (category (code B))
   (answer (topic correct-input-selected) (value yes))
   (answer (topic alt-video-cable-works) (value yes))
   =>
   (assert (action-log (step 3) (action "[B] Alternate video cable works - replacing faulty cable")))
   (assert (diagnosis (root-cause "Faulty video cable") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Faulty video cable") (solution "Replaced faulty video cable"))))

(defrule cat-B-faulty-monitor
   (declare (salience 85))
   (category (code B))
   (answer (topic alt-video-cable-works) (value no))
   (answer (topic alt-monitor-works) (value yes))
   =>
   (assert (action-log (step 3) (action "[B] Alternate monitor works - replacing/repairing faulty monitor")))
   (assert (diagnosis (root-cause "Faulty monitor") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Faulty monitor") (solution "Replaced/repaired faulty monitor"))))

(defrule cat-B-beep-codes
   (declare (salience 84))
   (category (code B))
   (answer (topic beep-codes-present) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[B] Beep codes/diagnostic lights present - recorded for hardware escalation")))
   (assert (escalation (target "Hardware / Level-2 Technician") (reason "Beep codes/diagnostic lights indicate hardware fault") (priority MEDIUM))))

(defrule cat-B-fallback
   (declare (salience 70))
   (category (code B))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[B] No display after basic checks")))
   (assert (diagnosis (root-cause "Undetermined display issue") (resolved no)))
   (assert (escalation (target "Hardware / Level-2 Technician") (reason "No display after basic checks - escalate for hardware diagnosis") (priority MEDIUM))))


;; ============================================================
;; CATEGORY C - COMPUTER IS RUNNING SLOWLY
;; ============================================================

(defrule cat-C-malware-alert
   (declare (salience 90))
   (category (code C))
   (answer (topic malware-alert) (value yes))
   =>
   (assert (action-log (step 3) (action "[C] Malware/security alert present - following security procedure")))
   (assert (escalation (target "Security / Administrator") (reason "Malware/security alert detected during performance troubleshooting") (priority HIGH))))

(defrule cat-C-high-usage
   (declare (salience 89))
   (category (code C))
   (answer (topic malware-alert) (value no))
   (answer (topic high-resource-usage) (value yes))
   =>
   (assert (action-log (step 3) (action "[C] High CPU/RAM usage or many open applications - closed apps and restarted")))
   (assert (diagnosis (root-cause "High resource usage from open applications") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "High resource usage") (solution "Closed unnecessary applications and restarted"))))

(defrule cat-C-low-disk
   (declare (salience 88))
   (category (code C))
   (answer (topic malware-alert) (value no))
   (answer (topic low-disk-space) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[C] Low disk space - freed unnecessary disk space")))
   (assert (diagnosis (root-cause "Low disk space") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Low disk space") (solution "Freed unnecessary disk space"))))

(defrule cat-C-startup-apps
   (declare (salience 87))
   (category (code C))
   (answer (topic malware-alert) (value no))
   (answer (topic many-startup-apps) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[C] Many startup applications - disabled unnecessary startup items and restarted")))
   (assert (diagnosis (root-cause "Excessive startup applications") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Excessive startup applications") (solution "Disabled unnecessary startup items"))))

(defrule cat-C-pending-updates
   (declare (salience 86))
   (category (code C))
   (answer (topic malware-alert) (value no))
   (answer (topic pending-updates) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[C] Pending OS/software updates - applied approved updates and restarted")))
   (assert (diagnosis (root-cause "Pending OS/software updates") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Pending updates") (solution "Applied approved updates and restarted"))))

(defrule cat-C-overheating-fixed
   (declare (salience 85))
   (category (code C))
   (answer (topic malware-alert) (value no))
   (answer (topic overheating) (value yes))
   (answer (topic still-overheating-after-vent) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[C] Overheating - improved ventilation and cleared external vents")))
   (assert (diagnosis (root-cause "Overheating due to blocked ventilation") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Overheating") (solution "Improved ventilation, cleared vents"))))

(defrule cat-C-overheating-persists
   (declare (salience 84))
   (category (code C))
   (answer (topic overheating) (value yes))
   (answer (topic still-overheating-after-vent) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[C] Overheating persists after ventilation fix - escalating for internal cleaning/hardware check")))
   (assert (escalation (target "Hardware / Level-2 Technician") (reason "Persistent overheating after ventilation improvements") (priority MEDIUM))))

(defrule cat-C-fallback
   (declare (salience 70))
   (category (code C))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[C] Computer remains slow after standard troubleshooting")))
   (assert (diagnosis (root-cause "Undetermined performance issue") (resolved no)))
   (assert (escalation (target "Level-2 Technician") (reason "Escalated for deeper performance diagnosis") (priority MEDIUM))))


;; ============================================================
;; CATEGORY D - KEYBOARD OR MOUSE NOT WORKING
;; ============================================================

(defrule cat-D-cable-loose
   (declare (salience 90))
   (category (code D))
   (answer (topic cable-loose) (value yes))
   =>
   (assert (action-log (step 3) (action "[D] Wired device cable loose - reconnected")))
   (assert (diagnosis (root-cause "Loose peripheral cable") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Loose cable") (solution "Reconnected cable"))))

(defrule cat-D-usb-port-faulty
   (declare (salience 89))
   (category (code D))
   (answer (topic cable-loose) (value no))
   (answer (topic usb-port-faulty) (value yes))
   =>
   (assert (action-log (step 3) (action "[D] Faulty USB connection - used different USB port")))
   (assert (diagnosis (root-cause "Faulty USB port") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Faulty USB port") (solution "Switched to different USB port"))))

(defrule cat-D-batteries-low
   (declare (salience 88))
   (category (code D))
   (answer (topic is-wireless) (value yes))
   (answer (topic batteries-low) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[D] Wireless device batteries low - replaced batteries")))
   (assert (diagnosis (root-cause "Low batteries") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Low batteries") (solution "Replaced batteries"))))

(defrule cat-D-switch-off
   (declare (salience 87))
   (category (code D))
   (answer (topic is-wireless) (value yes))
   (answer (topic wireless-switch-off) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[D] Wireless device power switch off - turned device on")))
   (assert (diagnosis (root-cause "Wireless device switched off") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Device power switch off") (solution "Turned device on"))))

(defrule cat-D-receiver-disconnected
   (declare (salience 86))
   (category (code D))
   (answer (topic is-wireless) (value yes))
   (answer (topic receiver-disconnected) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[D] Wireless receiver disconnected - reconnected receiver")))
   (assert (diagnosis (root-cause "Disconnected wireless receiver") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Disconnected receiver") (solution "Reconnected wireless receiver"))))

(defrule cat-D-works-elsewhere
   (declare (salience 85))
   (category (code D))
   (answer (topic works-on-other-computer) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[D] Device works on another computer - checked original computer's ports, drivers and settings")))
   (assert (diagnosis (root-cause "Driver/USB/settings issue on original computer") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Driver/settings issue") (solution "Corrected drivers/USB ports/settings on original computer"))))

(defrule cat-D-replace-device
   (declare (salience 84))
   (category (code D))
   (answer (topic works-on-other-computer) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[D] Device fails on another computer too - replacing keyboard/mouse")))
   (assert (diagnosis (root-cause "Faulty keyboard/mouse") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Faulty peripheral") (solution "Replaced keyboard/mouse"))))

(defrule cat-D-fallback
   (declare (salience 70))
   (category (code D))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[D] Peripheral issue remains after standard checks")))
   (assert (diagnosis (root-cause "Undetermined peripheral issue") (resolved no)))
   (assert (escalation (target "Hardware / Level-2 Technician") (reason "Escalate or replace peripheral") (priority LOW))))


;; ============================================================
;; CATEGORY E - NO INTERNET / WI-FI PROBLEM
;; ============================================================

(defrule cat-E-adapter-disabled
   (declare (salience 95))
   (category (code E))
   (answer (topic adapter-disabled) (value yes))
   =>
   (assert (action-log (step 3) (action "[E] Wi-Fi/Ethernet adapter disabled - enabled network adapter")))
   (assert (diagnosis (root-cause "Network adapter disabled") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Disabled network adapter") (solution "Enabled network adapter"))))

(defrule cat-E-wrong-network
   (declare (salience 94))
   (category (code E))
   (answer (topic adapter-disabled) (value no))
   (answer (topic wrong-network) (value yes))
   =>
   (assert (action-log (step 3) (action "[E] Connected to wrong network - connected to correct SSID/network")))
   (assert (diagnosis (root-cause "Connected to wrong network") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Wrong network selected") (solution "Connected to correct SSID"))))

(defrule cat-E-weak-signal-infra
   (declare (salience 93))
   (category (code E))
   (answer (topic weak-signal) (value yes))
   (answer (topic many-users-weak-signal) (value yes))
   =>
   (assert (action-log (step 3) (action "[E] Weak Wi-Fi signal affecting many users - suspected coverage/infrastructure problem")))
   (assert (escalation (target "Network Administrator") (reason "Weak signal affecting multiple users - suspected infrastructure issue (R4)") (priority HIGH))))

(defrule cat-E-weak-signal-local
   (declare (salience 92))
   (category (code E))
   (answer (topic weak-signal) (value yes))
   (answer (topic many-users-weak-signal) (value no))
   =>
   (assert (action-log (step 3) (action "[E] Weak Wi-Fi signal - moved closer to access point / removed obstacles")))
   (assert (diagnosis (root-cause "Weak Wi-Fi signal at user location") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Weak signal") (solution "Relocated closer to access point / removed interference"))))

(defrule cat-E-router-off-fixed
   (declare (salience 91))
   (category (code E))
   (answer (topic router-power-light-off) (value yes))
   (answer (topic router-power-restored) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[E] Router power light off - checked cable/adapter/outlet and restored power")))
   (assert (diagnosis (root-cause "Router lost power") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Router power loss") (solution "Restored router power via cable/adapter/outlet check"))))

(defrule cat-E-router-off-unresolved
   (declare (salience 90))
   (category (code E))
   (answer (topic router-power-light-off) (value yes))
   (answer (topic router-power-restored) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[E] Router remains off after power checks")))
   (assert (escalation (target "Network Administrator") (reason "Router remains without power after basic checks") (priority HIGH))))

(defrule cat-E-shared-outage-fixed
   (declare (salience 89))
   (category (code E))
   (answer (topic connected-no-internet) (value yes))
   (answer (topic other-devices-no-internet) (value yes))
   (answer (topic router-restart-fixed) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[E] Connected with no internet, affecting other devices too - restarted router, internet restored")))
   (assert (diagnosis (root-cause "Router/modem required restart") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Router/modem needed restart") (solution "Restarted router/modem (authorized)"))))

(defrule cat-E-shared-outage-unresolved
   (declare (salience 88))
   (category (code E))
   (answer (topic connected-no-internet) (value yes))
   (answer (topic other-devices-no-internet) (value yes))
   (answer (topic router-restart-fixed) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[E] Internet did not return after router restart - suspected network/ISP outage")))
   (assert (escalation (target "Network Administrator") (reason "Suspected network/ISP outage - internet not restored after router restart") (priority HIGH))))

(defrule cat-E-device-only-fixed
   (declare (salience 87))
   (category (code E))
   (answer (topic connected-no-internet) (value yes))
   (answer (topic other-devices-no-internet) (value no))
   (answer (topic device-network-fix-worked) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[E] Only this device affected - corrected IP/DNS/network settings")))
   (assert (diagnosis (root-cause "Misconfigured IP/DNS/network settings on this device") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Device network misconfiguration") (solution "Corrected IP/DNS/network settings"))))

(defrule cat-E-device-only-unresolved
   (declare (salience 86))
   (category (code E))
   (answer (topic connected-no-internet) (value yes))
   (answer (topic other-devices-no-internet) (value no))
   (answer (topic device-network-fix-worked) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[E] Device network settings correction did not resolve issue")))
   (assert (escalation (target "Network Administrator") (reason "Device-specific network configuration issue unresolved") (priority MEDIUM))))

(defrule cat-E-fallback
   (declare (salience 70))
   (category (code E))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[E] Standard network troubleshooting did not resolve the issue")))
   (assert (diagnosis (root-cause "Undetermined network issue") (resolved no)))
   (assert (escalation (target "Network Administrator") (reason "Escalated for network diagnosis") (priority MEDIUM))))


;; ============================================================
;; CATEGORY F - APPLICATION DOES NOT OPEN / CRASHES
;; ============================================================

(defrule cat-F-app-outdated
   (declare (salience 90))
   (category (code F))
   (answer (topic app-outdated) (value yes))
   =>
   (assert (action-log (step 3) (action "[F] Application outdated - updated application")))
   (assert (diagnosis (root-cause "Outdated application") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Outdated application") (solution "Updated application"))))

(defrule cat-F-os-outdated
   (declare (salience 89))
   (category (code F))
   (answer (topic app-outdated) (value no))
   (answer (topic os-outdated) (value yes))
   =>
   (assert (action-log (step 3) (action "[F] Operating system outdated - applied approved OS updates")))
   (assert (diagnosis (root-cause "Outdated operating system") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Outdated OS") (solution "Applied approved OS updates"))))

(defrule cat-F-low-resources
   (declare (salience 88))
   (category (code F))
   (answer (topic os-outdated) (value no))
   (answer (topic low-memory-disk) (value yes))
   =>
   (assert (action-log (step 3) (action "[F] Insufficient memory/disk space - closed programs, freed space, restarted")))
   (assert (diagnosis (root-cause "Insufficient memory or disk space") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Insufficient resources") (solution "Freed memory/disk space and restarted"))))

(defrule cat-F-repair-works
   (declare (salience 87))
   (category (code F))
   (answer (topic repair-available) (value yes))
   (answer (topic still-crashes-after-repair) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[F] Repair/reset available - ran approved repair/reset")))
   (assert (diagnosis (root-cause "Corrupted application files/settings") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Corrupted application files") (solution "Ran approved repair/reset"))))

(defrule cat-F-reinstall-works
   (declare (salience 86))
   (category (code F))
   (answer (topic still-crashes-after-repair) (value yes))
   (answer (topic reinstall-allowed) (value yes))
   (answer (topic still-fails-after-reinstall) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[F] Reinstalled application per policy - issue resolved")))
   (assert (diagnosis (root-cause "Corrupted application installation") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Corrupted installation") (solution "Reinstalled application"))))

(defrule cat-F-still-fails
   (declare (salience 85))
   (category (code F))
   (answer (topic still-fails-after-reinstall) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[F] Application still fails after reinstall - collected logs and error information")))
   (assert (escalation (target "Level-2 Technician") (reason "Application crashes persist after full standard remediation; logs collected") (priority MEDIUM))))

(defrule cat-F-fallback-close
   (declare (salience 70))
   (category (code F))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[F] No further reproducible symptoms after standard checks - documenting and closing per procedure")))
   (assert (diagnosis (root-cause "Application issue addressed via standard checks; not reproducible") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Application crash - resolved via standard checks") (solution "Standard checks applied; issue not reproducible"))))


;; ============================================================
;; CATEGORY G - PRINTER DOES NOT PRINT / POOR QUALITY
;; ============================================================

(defrule cat-G-printer-off
   (declare (salience 95))
   (category (code G))
   (answer (topic printer-off) (value yes))
   =>
   (assert (action-log (step 3) (action "[G] Printer powered off - powered it on")))
   (assert (diagnosis (root-cause "Printer was powered off") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Printer off") (solution "Powered on printer"))))

(defrule cat-G-printer-offline
   (declare (salience 94))
   (category (code G))
   (answer (topic printer-off) (value no))
   (answer (topic printer-offline) (value yes))
   =>
   (assert (action-log (step 3) (action "[G] Printer offline - set printer online")))
   (assert (diagnosis (root-cause "Printer set offline") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Printer offline") (solution "Set printer online"))))

(defrule cat-G-paper-empty
   (declare (salience 93))
   (category (code G))
   (answer (topic paper-empty) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Paper tray empty - added paper")))
   (assert (diagnosis (root-cause "Paper tray empty") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Out of paper") (solution "Added paper"))))

(defrule cat-G-paper-jam
   (declare (salience 92))
   (category (code G))
   (answer (topic paper-jammed) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Paper jam - cleared jam safely")))
   (assert (diagnosis (root-cause "Paper jam") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Paper jam") (solution "Cleared paper jam"))))

(defrule cat-G-consumable-empty
   (declare (salience 91))
   (category (code G))
   (answer (topic consumable-empty) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Ink/toner empty - replaced approved consumable")))
   (assert (diagnosis (root-cause "Ink/toner empty") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Out of ink/toner") (solution "Replaced consumable"))))

(defrule cat-G-queue-stuck
   (declare (salience 90))
   (category (code G))
   (answer (topic queue-stuck) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Print queue had stuck jobs - cleared queue and restarted printer")))
   (assert (diagnosis (root-cause "Stuck print queue") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Stuck print queue") (solution "Cleared print queue, restarted printer"))))

(defrule cat-G-wrong-printer
   (declare (salience 89))
   (category (code G))
   (answer (topic wrong-printer-selected) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Wrong printer selected - selected correct printer")))
   (assert (diagnosis (root-cause "Wrong printer selected") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Wrong printer selected") (solution "Selected correct printer"))))

(defrule cat-G-not-detected-local
   (declare (salience 88))
   (category (code G))
   (answer (topic printer-not-detected) (value yes))
   (answer (topic detected-by-other-computer) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Printer not detected on this computer but detected elsewhere - checked local driver/settings")))
   (assert (diagnosis (root-cause "Local driver/settings issue") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Local driver/settings issue") (solution "Corrected local driver/settings"))))

(defrule cat-G-not-detected-network
   (declare (salience 87))
   (category (code G))
   (answer (topic printer-not-detected) (value yes))
   (answer (topic detected-by-other-computer) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Printer not detected by any computer - suspected network/print server issue")))
   (assert (escalation (target "Network Administrator") (reason "Printer not detected by any computer - network/print server issue") (priority MEDIUM))))

(defrule cat-G-quality-fixed
   (declare (salience 86))
   (category (code G))
   (answer (topic print-quality-poor) (value yes))
   (answer (topic quality-after-cleaning-poor) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Poor print quality - checked ink/paper/settings, ran cleaning/calibration")))
   (assert (diagnosis (root-cause "Print quality degraded (settings/consumables)") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Poor print quality") (solution "Adjusted settings, ran cleaning/calibration"))))

(defrule cat-G-quality-persists
   (declare (salience 85))
   (category (code G))
   (answer (topic print-quality-poor) (value yes))
   (answer (topic quality-after-cleaning-poor) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[G] Print quality remains poor after cleaning - replaced consumable")))
   (assert (diagnosis (root-cause "Consumable/hardware causing poor quality") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Poor print quality") (solution "Replaced consumable after cleaning did not resolve"))))

(defrule cat-G-fallback
   (declare (salience 70))
   (category (code G))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[G] Printer issue remains after standard checks")))
   (assert (diagnosis (root-cause "Undetermined printer issue") (resolved no)))
   (assert (escalation (target "Hardware / Level-2 Technician") (reason "Escalate printer/hardware issue") (priority LOW))))


;; ============================================================
;; CATEGORY H - PASSWORD FORGOTTEN / ACCOUNT LOCKED
;; ============================================================

(defrule cat-H-security-suspected
   (declare (salience 90))
   (category (code H))
   (answer (topic security-incident-suspected) (value yes))
   =>
   (assert (action-log (step 3) (action "[H] Security incident suspected during account issue - halting normal account actions")))
   (assert (escalation (target "Security / Administrator") (reason "Suspected security incident during password/account troubleshooting") (priority CRITICAL))))

(defrule cat-H-admin-required
   (declare (salience 89))
   (category (code H))
   (answer (topic security-incident-suspected) (value no))
   (answer (topic account-disabled-or-admin-required) (value yes))
   =>
   (assert (action-log (step 3) (action "[H] Account disabled or requires administrator privileges")))
   (assert (escalation (target "System Administrator") (reason "Account disabled or requires elevated privileges") (priority MEDIUM))))

(defrule cat-H-identity-not-verified
   (declare (salience 88))
   (category (code H))
   (answer (topic security-incident-suspected) (value no))
   (answer (topic account-disabled-or-admin-required) (value no))
   (answer (topic identity-verified) (value no))
   =>
   (assert (action-log (step 3) (action "[H] Identity could not be verified - reset/unlock withheld")))
   (assert (escalation (target "System Administrator") (reason "Identity verification failed - reset/unlock withheld per policy") (priority MEDIUM))))

(defrule cat-H-self-service-reset
   (declare (salience 87))
   (category (code H))
   (answer (topic identity-verified) (value yes))
   (answer (topic self-service-available) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[H] Self-service password reset available - used self-service reset")))
   (assert (diagnosis (root-cause "User forgot password") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Forgotten password") (solution "Resolved via approved self-service password reset"))))

(defrule cat-H-manual-reset
   (declare (salience 86))
   (category (code H))
   (answer (topic identity-verified) (value yes))
   (answer (topic self-service-available) (value no))
   (answer (topic account-locked) (value no))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[H] Self-service unavailable - identity verified, password reset per policy")))
   (assert (diagnosis (root-cause "User forgot password, self-service unavailable") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Forgotten password") (solution "Identity verified; password reset manually per policy"))))

(defrule cat-H-unlock-account
   (declare (salience 85))
   (category (code H))
   (answer (topic identity-verified) (value yes))
   (answer (topic account-locked) (value yes))
   (not (diagnosis))
   =>
   (assert (action-log (step 3) (action "[H] Account locked - identity verified, unlocking per policy")))
   (assert (diagnosis (root-cause "Account became locked") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Account locked") (solution "Identity verified; account unlocked per policy"))))

(defrule cat-H-repeatedly-locked
   (declare (salience 84))
   (category (code H))
   (answer (topic repeatedly-locked) (value yes))
   (not (ticket))
   =>
   (assert (action-log (step 3) (action "[H] Account repeatedly becomes locked - investigating saved credentials/devices for possible compromise")))
   (assert (escalation (target "Security / Administrator") (reason "Account repeatedly locked - possible compromise or stale saved credentials") (priority MEDIUM))))

(defrule cat-H-fallback
   (declare (salience 70))
   (category (code H))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[H] Standard account procedures applied")))
   (assert (diagnosis (root-cause "Password/account issue addressed via standard procedure") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Password/account issue") (solution "Resolved via standard password/account procedure"))))


;; ============================================================
;; CATEGORY I - OTHER / UNKNOWN PROBLEM   (R13)
;; ============================================================

(defrule cat-I-level1-resolved
   (declare (salience 90))
   (category (code I))
   (answer (topic level1-available) (value yes))
   (answer (topic resolved-after-level1) (value yes))
   =>
   (assert (action-log (step 3) (action "[I] Standard Level-1 troubleshooting applied and resolved the issue")))
   (assert (diagnosis (root-cause "Miscellaneous issue resolved via standard Level-1 procedure") (resolved yes)))
   (assert (ticket (status CLOSED) (priority LOW) (root-cause "Miscellaneous issue") (solution "Resolved via applicable Level-1 rule"))))

(defrule cat-I-level1-unresolved
   (declare (salience 89))
   (category (code I))
   (answer (topic level1-available) (value yes))
   (answer (topic resolved-after-level1) (value no))
   =>
   (assert (action-log (step 3) (action "[I] Level-1 troubleshooting applied but problem remains")))
   (assert (escalation (target "Level-2 / Level-3 Technician") (reason "Level-1 troubleshooting exhausted without resolution (R11)") (priority MEDIUM))))

(defrule cat-I-no-rule
   (declare (salience 88))
   (category (code I))
   (answer (topic level1-available) (value no))
   =>
   (assert (action-log (step 3) (action "[I] No applicable Level-1 rule exists - recording symptoms")))
   (assert (escalation (target "Level-2 / Level-3 Technician") (reason "No applicable rule (R13) - recorded symptoms for further diagnosis") (priority MEDIUM))))

(defrule cat-I-fallback
   (declare (salience 70))
   (category (code I))
   (not (diagnosis))
   (not (escalation))
   =>
   (assert (action-log (step 3) (action "[I] Unable to classify or resolve automatically")))
   (assert (escalation (target "Level-2 / Level-3 Technician") (reason "Unclassified issue (R13)") (priority MEDIUM))))


;; ============================================================
;; STEP 5 - SEVERITY / PRIORITY   (R4)
;; Raise priority to HIGH when multiple users/devices are
;; affected, regardless of which category fired.
;; ============================================================

(defrule bump-escalation-priority-multiple-users
   (declare (salience 60))
   (case-info (other-users-affected yes))
   ?e <- (escalation (priority ?p&MEDIUM|LOW))
   =>
   (modify ?e (priority HIGH))
   (assert (action-log (step 5) (action "Priority raised to HIGH - multiple users/devices affected (R4)"))))


;; ============================================================
;; STEP 6 - TICKET COMPILATION
;; ============================================================

(defrule compile-ticket-from-escalation
   (declare (salience 10))
   (escalation (target ?t) (reason ?r) (priority ?p))
   (not (ticket))
   =>
   (assert (ticket (status ESCALATED) (priority ?p) (root-cause ?r)
                   (solution (str-cat "Escalated to " ?t)))))

(defrule bump-ticket-priority-multiple-users
   (declare (salience 5))
   (case-info (other-users-affected yes))
   ?t <- (ticket (priority ?p&MEDIUM|LOW) (status ~CLOSED))
   =>
   (modify ?t (priority HIGH))
   (assert (action-log (step 5) (action "Ticket priority raised to HIGH - multiple users/devices affected (R4)"))))

;; Safety net: R13 - if nothing else ever fired, escalate for
;; manual diagnosis rather than silently doing nothing.
(defrule no-applicable-rule
   (declare (salience 1))
   (not (diagnosis))
   (not (escalation))
   (not (ticket))
   =>
   (assert (action-log (step 6) (action "No applicable automated rule found - recording symptoms and escalating (R13)")))
   (assert (escalation (target "Level-2 / Level-3 Technician") (reason "No applicable Level-1 rule") (priority MEDIUM)))
   (assert (ticket (status ESCALATED) (priority MEDIUM) (root-cause "Unclassified issue") (solution "Escalated for further diagnosis"))))
