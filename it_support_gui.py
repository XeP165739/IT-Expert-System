import os
import sys
import tkinter as tk
from tkinter import ttk, messagebox

try:
    import clips
except ImportError:
    sys.exit(
        "This script requires the 'clipspy' package.\n"
        "Install it with:  pip install clipspy"
    )

CLP_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "it_support_expert_system.clp",
)

CATEGORY_MENU = {
    "A": "Computer does not turn on / no power",
    "B": "Computer turns on but no display",
    "C": "Computer is running slowly",
    "D": "Keyboard or mouse not working",
    "E": "No internet / Wi-Fi problem",
    "F": "Application does not open / crashes",
    "G": "Printer does not print / poor quality",
    "H": "Password forgotten / account locked",
    "I": "Other / unknown problem",
}

CATEGORY_QUESTIONS = {
    "A": [
        ("power-cable-connected", "Is the power cable connected?"),
        ("outlet-working", "Does the electrical outlet / power strip work?"),
        ("is-laptop", "Is this a laptop?"),
        ("adapter-suspect", "Is the power adapter suspect (e.g. swapped, no change)?"),
        ("power-button-response", "Power button response", ["some", "none"]),
    ],
    "B": [
        ("monitor-powered-on", "Is the monitor powered on?"),
        ("monitor-power-cable-loose", "Is the monitor's power cable loose?"),
        ("video-cable-loose", "Is the video cable loose?"),
        ("correct-input-selected", "Is the correct monitor input/source selected?"),
        ("alt-video-cable-works", "Does the display work with another video cable?"),
        ("alt-monitor-works", "Does another known-good monitor work?"),
        ("beep-codes-present", "Are beep codes or diagnostic lights present?"),
    ],
    "C": [
        ("malware-alert", "Is there a malware / security alert?"),
        ("high-resource-usage", "Is CPU/RAM usage high or many apps open?"),
        ("low-disk-space", "Is disk space low?"),
        ("many-startup-apps", "Are many startup applications running?"),
        ("pending-updates", "Are there pending OS/software updates?"),
        ("overheating", "Is the computer overheating?"),
        ("still-overheating-after-vent", "Still overheating after ventilation?"),
    ],
    "D": [
        ("cable-loose", "If wired, is the device cable loose?"),
        ("usb-port-faulty", "Is the USB connection faulty?"),
        ("is-wireless", "Is this a wireless keyboard/mouse?"),
        ("batteries-low", "Are the batteries low?"),
        ("wireless-switch-off", "Is the wireless power switch off?"),
        ("receiver-disconnected", "Is the wireless receiver disconnected?"),
        ("works-on-other-computer", "Does the device work on another computer?"),
    ],
    "E": [
        ("adapter-disabled", "Is the Wi-Fi/Ethernet adapter disabled?"),
        ("wrong-network", "Is the device connected to the wrong network?"),
        ("weak-signal", "Is the Wi-Fi signal weak?"),
        ("many-users-weak-signal", "Do many users experience weak signal?"),
        ("connected-no-internet", "Connected but no internet access?"),
        ("other-devices-no-internet", "Do other devices also have no internet?"),
        ("router-restart-fixed", "Did restarting the router/modem fix it?"),
        ("device-network-fix-worked", "Did adjusting IP/DNS settings fix it?"),
        ("router-power-light-off", "Is the router's power light off?"),
        ("router-power-restored", "Is router power restored after checks?"),
    ],
    "F": [
        ("app-outdated", "Is the application outdated?"),
        ("os-outdated", "Is the operating system outdated?"),
        ("low-memory-disk", "Is memory or disk space insufficient?"),
        ("repair-available", "Is an app repair/reset option available?"),
        ("still-crashes-after-repair", "Does app still crash after repair?"),
        ("reinstall-allowed", "Is reinstallation allowed by policy?"),
        ("still-fails-after-reinstall", "Does it still fail after reinstalling?"),
    ],
    "G": [
        ("printer-off", "Is the printer powered off?"),
        ("printer-offline", "Is the printer offline?"),
        ("paper-empty", "Is the paper tray empty?"),
        ("paper-jammed", "Is there a paper jam?"),
        ("consumable-empty", "Is ink or toner empty?"),
        ("queue-stuck", "Does the print queue contain stuck jobs?"),
        ("wrong-printer-selected", "Is the wrong printer selected?"),
        ("printer-not-detected", "Is the printer not being detected?"),
        ("detected-by-other-computer", "Can another computer detect it?"),
        ("print-quality-poor", "Is print quality poor?"),
        ("quality-after-cleaning-poor", "Is quality still poor after cleaning?"),
    ],
    "H": [
        ("security-incident-suspected", "Security incident suspected for account?"),
        ("account-disabled-or-admin-required", "Disabled or requires admin privileges?"),
        ("identity-verified", "Can the user's identity be verified?"),
        ("self-service-available", "Is self-service password reset available?"),
        ("account-locked", "Is the account locked?"),
        ("repeatedly-locked", "Does the account repeatedly become locked?"),
    ],
    "I": [
        ("level1-available", "Is a standard Level-1 step available?"),
        ("resolved-after-level1", "Did Level-1 step resolve the problem?"),
    ]
}


class ITSupportGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("IT Support Expert System")
        self.geometry("750x600")
        self.minsize(650, 500)

        self.env = clips.Environment()
        self.load_clips_file()

        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill="both", expand=True, padx=10, pady=10)

        # Tab 1: Basic Info
        self.tab_basic = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_basic, text="1. Basic Info")
        self.setup_basic_tab()

        # Tab 2: Critical Check
        self.tab_critical = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_critical, text="2. Critical Check")
        self.setup_critical_tab()

        # Tab 3: Troubleshooting Questions
        self.tab_category = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_category, text="3. Category & Assessment")
        self.setup_category_tab()

        # Tab 4: Results
        self.tab_report = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_report, text="4. Ticket Report")
        self.setup_report_tab()

        self.toggle_tabs(step1=True, step2=False, step3=False, step4=False)

    def load_clips_file(self):
        try:
            self.env.load(CLP_FILE)
            self.env.reset()
        except Exception as e:
            messagebox.showerror("CLIPS Error", f"Failed to load rules file:\n{e}")

    def esc(self, text):
        return str(text).replace('"', "'")

    def toggle_tabs(self, step1, step2, step3, step4):
        self.notebook.tab(self.tab_basic, state="normal" if step1 else "disabled")
        self.notebook.tab(self.tab_critical, state="normal" if step2 else "disabled")
        self.notebook.tab(self.tab_category, state="normal" if step3 else "disabled")
        self.notebook.tab(self.tab_report, state="normal" if step4 else "disabled")

    # --- TAB 1: BASIC INFO ---
    def setup_basic_tab(self):
        frame = ttk.LabelFrame(self.tab_basic, text=" Case Details ", padding=15)
        frame.pack(fill="both", expand=True, padx=10, pady=10)

        fields = [
            ("User Name", "user_name"),
            ("Contact Info", "contact"),
            ("Device / Asset ID", "device_id"),
            ("Location", "location"),
            ("Problem Description", "problem_desc"),
            ("Start Time", "start_time"),
            ("Error Message", "error_message"),
            ("User Activity", "activity"),
            ("Prior Attempts", "prior"),
        ]

        self.entries = {}
        for idx, (label_text, key) in enumerate(fields):
            ttk.Label(frame, text=f"{label_text}:").grid(row=idx, column=0, sticky="w", pady=3)
            entry = ttk.Entry(frame, width=45)
            entry.grid(row=idx, column=1, sticky="ew", pady=3, padx=5)
            self.entries[key] = entry

        ttk.Label(frame, text="Other users affected?").grid(row=len(fields), column=0, sticky="w", pady=3)
        self.other_users_var = tk.StringVar(value="no")
        ttk.OptionMenu(frame, self.other_users_var, "no", "yes", "no").grid(row=len(fields), column=1, sticky="w", padx=5)

        frame.columnconfigure(1, weight=1)

        btn_next = ttk.Button(self.tab_basic, text="Next: Critical Checks →", command=self.process_basic_info)
        btn_next.pack(side="right", padx=15, pady=10)

    def process_basic_info(self):
        user_name = self.entries["user_name"].get().strip()
        device_id = self.entries["device_id"].get().strip()
        location = self.entries["location"].get().strip()
        problem_desc = self.entries["problem_desc"].get().strip()
        start_time = self.entries["start_time"].get().strip()
        error_message = self.entries["error_message"].get().strip() or "none"
        activity = self.entries["activity"].get().strip()
        prior = self.entries["prior"].get().strip() or "none"
        other_users = self.other_users_var.get()

        fact_str = (
            "(case-info "
            f'(user-name "{self.esc(user_name)}") '
            f'(device-id "{self.esc(device_id)}") '
            f'(location "{self.esc(location)}") '
            f'(problem-desc "{self.esc(problem_desc)}") '
            f'(start-time "{self.esc(start_time)}") '
            f'(error-message "{self.esc(error_message)}") '
            f'(activity "{self.esc(activity)}") '
            f'(prior-attempts "{self.esc(prior)}") '
            f"(other-users-affected {other_users}))"
        )
        self.env.assert_string(fact_str)

        self.toggle_tabs(step1=True, step2=True, step3=False, step4=False)
        self.notebook.select(self.tab_critical)

    # --- TAB 2: CRITICAL CHECKS ---
    def setup_critical_tab(self):
        frame = ttk.LabelFrame(self.tab_critical, text=" Critical Condition Triage ", padding=15)
        frame.pack(fill="both", expand=True, padx=10, pady=10)

        self.sec_var = tk.StringVar(value="no")
        self.data_var = tk.StringVar(value="no")
        self.sys_var = tk.StringVar(value="no")

        ttk.Label(frame, text="1. Security incident or malware infection suspected?").pack(anchor="w", pady=5)
        ttk.OptionMenu(frame, self.sec_var, "no", "yes", "no").pack(anchor="w", padx=20)

        ttk.Label(frame, text="2. Data loss or data corruption suspected?").pack(anchor="w", pady=5)
        ttk.OptionMenu(frame, self.data_var, "no", "yes", "no").pack(anchor="w", padx=20)

        ttk.Label(frame, text="3. Critical business system unavailable?").pack(anchor="w", pady=5)
        ttk.OptionMenu(frame, self.sys_var, "no", "yes", "no").pack(anchor="w", padx=20)

        btn_next = ttk.Button(self.tab_critical, text="Evaluate Triage →", command=self.process_critical_flags)
        btn_next.pack(side="right", padx=15, pady=10)

    def process_critical_flags(self):
        sec = self.sec_var.get()
        data = self.data_var.get()
        sys_down = self.sys_var.get()

        self.env.assert_string(
            "(critical-flags "
            f"(security-incident {sec}) "
            f"(data-loss {data}) "
            f"(critical-system-down {sys_down}))"
        )

        if sec == "yes" or data == "yes" or sys_down == "yes":
            self.run_clips_engine()
        else:
            self.toggle_tabs(step1=True, step2=True, step3=True, step4=False)
            self.notebook.select(self.tab_category)

    # --- TAB 3: CATEGORY & ASSESSMENT ---
    def setup_category_tab(self):
        top_frame = ttk.Frame(self.tab_category, padding=10)
        top_frame.pack(fill="x")

        ttk.Label(top_frame, text="Select Category: ").pack(side="left")
        self.cat_var = tk.StringVar()
        cat_choices = [f"[{k}] {v}" for k, v in CATEGORY_MENU.items()]
        self.cat_menu = ttk.Combobox(top_frame, values=cat_choices, textvariable=self.cat_var, state="readonly", width=45)
        self.cat_menu.pack(side="left", padx=5)
        self.cat_menu.bind("<<ComboboxSelected>>", self.on_category_select)

        # Scrollable container for dynamically generated questions
        self.q_container = ttk.LabelFrame(self.tab_category, text=" Category Troubleshooting ", padding=10)
        self.q_container.pack(fill="both", expand=True, padx=10, pady=5)

        self.canvas = tk.Canvas(self.q_container, borderwidth=0)
        self.scrollbar = ttk.Scrollbar(self.q_container, orient="vertical", command=self.canvas.yview)
        self.q_frame = ttk.Frame(self.canvas)

        self.q_frame.bind("<Configure>", lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas.create_window((0, 0), window=self.q_frame, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)

        self.canvas.pack(side="left", fill="both", expand=True)
        self.scrollbar.pack(side="right", fill="y")

        self.cat_vars = {}

        btn_run = ttk.Button(self.tab_category, text="Process & Generate Ticket →", command=self.process_category_answers)
        btn_run.pack(side="right", padx=15, pady=10)

    def on_category_select(self, event=None):
        for widget in self.q_frame.winfo_children():
            widget.destroy()

        self.cat_vars.clear()
        selected_raw = self.cat_var.get()
        if not selected_raw:
            return

        cat_code = selected_raw[1]
        questions = CATEGORY_QUESTIONS.get(cat_code, [])

        for idx, q_info in enumerate(questions):
            topic = q_info[0]
            prompt = q_info[1]

            ttk.Label(self.q_frame, text=f"{prompt}").grid(row=idx, column=0, sticky="w", pady=4, padx=5)

            if len(q_info) == 3:
                options = q_info[2]
                var = tk.StringVar(value=options[0])
                om = ttk.OptionMenu(self.q_frame, var, options[0], *options)
                om.grid(row=idx, column=1, sticky="w", padx=5)
            else:
                var = tk.StringVar(value="no")
                om = ttk.OptionMenu(self.q_frame, var, "no", "yes", "no")
                om.grid(row=idx, column=1, sticky="w", padx=5)

            self.cat_vars[topic] = var

    def process_category_answers(self):
        selected_raw = self.cat_var.get()
        if not selected_raw:
            messagebox.showwarning("Missing Category", "Please select a problem category first.")
            return

        cat_code = selected_raw[1]
        self.env.assert_string(f"(category (code {cat_code}))")

        for topic, var in self.cat_vars.items():
            val = var.get().lower()
            self.env.assert_string(f"(answer (topic {topic}) (value {val}))")

        self.run_clips_engine()

    # --- STEP 4: RUN ENGINE & SHOW REPORT ---
    def run_clips_engine(self):
        self.env.run()
        self.render_report()
        self.toggle_tabs(step1=True, step2=True, step3=True, step4=True)
        self.notebook.select(self.tab_report)

    def setup_report_tab(self):
        frame = ttk.Frame(self.tab_report, padding=10)
        frame.pack(fill="both", expand=True)

        self.txt_report = tk.Text(frame, wrap="word", font=("Consolas", 10))
        scroll = ttk.Scrollbar(frame, orient="vertical", command=self.txt_report.yview)
        self.txt_report.configure(yscrollcommand=scroll.set)

        self.txt_report.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")

        btn_reset = ttk.Button(self.tab_report, text="New Assessment", command=self.reset_system)
        btn_reset.pack(side="right", padx=15, pady=10)

    def get_facts_by_template(self, template_name):
        return [f for f in self.env.facts() if f.template.name == template_name]

    def render_report(self):
        self.txt_report.delete("1.0", tk.END)

        out = ["=" * 60, "TICKET REPORT", "=" * 60, ""]

        logs = self.get_facts_by_template("action-log")
        if logs:
            out.append("-- Troubleshooting Trace --")
            for f in sorted(logs, key=lambda x: x["step"]):
                out.append(f"  Step {f['step']}: {f['action']}")
            out.append("")

        diagnoses = self.get_facts_by_template("diagnosis")
        if diagnoses:
            out.append("-- Diagnosis --")
            for d in diagnoses:
                out.append(f"  Root Cause             : {d['root-cause']}")
                out.append(f"  Resolved Automatically : {d['resolved']}")
            out.append("")

        escalations = self.get_facts_by_template("escalation")
        if escalations:
            out.append("-- Escalation --")
            for e in escalations:
                out.append(f"  Escalated To : {e['target']}")
                out.append(f"  Reason       : {e['reason']}")
                out.append(f"  Priority     : {e['priority']}")
            out.append("")

        tickets = self.get_facts_by_template("ticket")
        if tickets:
            out.append("-- Ticket --")
            for t in tickets:
                out.append(f"  Status     : {t['status']}")
                out.append(f"  Priority   : {t['priority']}")
                out.append(f"  Root Cause : {t['root-cause']}")
                out.append(f"  Solution   : {t['solution']}")
            out.append("")
        else:
            out.append("(No ticket fact was produced - check the rule base.)")

        out.append("=" * 60)
        self.txt_report.insert("1.0", "\n".join(out))

    def reset_system(self):
        self.env.reset()
        for entry in self.entries.values():
            entry.delete(0, tk.END)
        self.other_users_var.set("no")
        self.sec_var.set("no")
        self.data_var.set("no")
        self.sys_var.set("no")
        self.cat_var.set("")
        self.on_category_select()
        self.toggle_tabs(step1=True, step2=False, step3=False, step4=False)
        self.notebook.select(self.tab_basic)


if __name__ == "__main__":
    app = ITSupportGUI()
    app.mainloop()