"""
IT Support Expert System - Python I/O Layer
=============================================
Architecture (deliberate separation of concerns, as required for a
proper expert system design):

    CLIPS  (it_support_expert_system.clp)
        -> owns ALL decision logic: the troubleshooting tree,
           critical-condition checks, category branching,
           severity/priority rules, and escalation rules.
           Implemented as deftemplates + defrules (forward chaining).

    Python (this file)
        -> owns ALL interaction with the human technician:
           asking questions in the right order, validating input,
           asserting the answers as CLIPS facts, running the
           inference engine, and reading back / formatting the
           resulting ticket. Contains NO decision logic itself -
           it only decides *which question to ask next*, mirroring
           the same branch order encoded in the .clp rules.

Requires:
    pip install clipspy

Run:
    python it_support_expert_system.py
"""

import os
import sys

try:
    import clips
except ImportError:
    sys.exit(
        "This script requires the 'clipspy' package.\n"
        "Install it with:  pip install clipspy\n"
        "(clipspy provides Python bindings to the CLIPS C engine.)"
    )

CLP_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "it_support_expert_system.clp",
)


# ----------------------------------------------------------------------
# Generic input helpers
# ----------------------------------------------------------------------

def ask_yes_no(prompt):
    while True:
        ans = input(f"{prompt} (yes/no): ").strip().lower()
        if ans in ("y", "yes"):
            return "yes"
        if ans in ("n", "no"):
            return "no"
        print("  Please answer 'yes' or 'no'.")


def ask_text(prompt, default=""):
    ans = input(f"{prompt}: ").strip()
    return ans if ans else default


def ask_choice(prompt, choices):
    choices_upper = [c.upper() for c in choices]
    while True:
        ans = input(f"{prompt} [{'/'.join(choices)}]: ").strip().upper()
        if ans in choices_upper:
            return ans
        print(f"  Please choose one of: {', '.join(choices)}")


def esc(text):
    """Escape double quotes so a Python string can be embedded safely
    inside a CLIPS string literal."""
    return str(text).replace('"', "'")


# ----------------------------------------------------------------------
# STEP 1: Basic information
# ----------------------------------------------------------------------

def collect_basic_info(env):
    print("\n=== STEP 1: BASIC INFORMATION ===")
    user_name = ask_text("User name")
    contact = ask_text("Contact info (email/phone)")
    device_id = ask_text("Device name / asset number")
    location = ask_text("Location")
    problem_desc = ask_text("Briefly describe the problem")
    start_time = ask_text("When did the problem start")
    error_message = ask_text("Exact error message (if any)", default="none")
    activity = ask_text("What was the user doing when it happened")
    prior = ask_text("Troubleshooting already attempted", default="none")
    other_users = ask_yes_no(
        "Are other users/devices experiencing the same problem?"
    )

    fact_str = (
        "(case-info "
        f'(user-name "{esc(user_name)}") '
        f'(device-id "{esc(device_id)}") '
        f'(location "{esc(location)}") '
        f'(problem-desc "{esc(problem_desc)}") '
        f'(start-time "{esc(start_time)}") '
        f'(error-message "{esc(error_message)}") '
        f'(activity "{esc(activity)}") '
        f'(prior-attempts "{esc(prior)}") '
        f"(other-users-affected {other_users}))"
    )
    env.assert_string(fact_str)
    # contact info is kept locally for the human technician only -
    # it is not part of the CLIPS decision logic, so it is not asserted.
    print(f"  (contact on file: {contact})")


# ----------------------------------------------------------------------
# STEP 2: Critical conditions
# ----------------------------------------------------------------------

def collect_critical_flags(env):
    print("\n=== STEP 2: CRITICAL CONDITION CHECK (do this first) ===")
    security = ask_yes_no("Is a security incident / malware infection suspected?")
    data_loss = "no"
    critical_sys = "no"
    if security == "no":
        data_loss = ask_yes_no("Is data loss or corruption suspected?")
    if security == "no" and data_loss == "no":
        critical_sys = ask_yes_no("Is a critical business system unavailable?")

    env.assert_string(
        "(critical-flags "
        f"(security-incident {security}) "
        f"(data-loss {data_loss}) "
        f"(critical-system-down {critical_sys}))"
    )
    return security == "yes" or data_loss == "yes" or critical_sys == "yes"


# ----------------------------------------------------------------------
# STEP 3: Category classification + category-specific questions
# ----------------------------------------------------------------------

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


def choose_category():
    print("\n=== STEP 3: PROBLEM CATEGORY ===")
    for code, desc in CATEGORY_MENU.items():
        print(f"  [{code}] {desc}")
    return ask_choice("Select category", list(CATEGORY_MENU.keys()))


def assert_answer(env, topic, value):
    env.assert_string(f"(answer (topic {topic}) (value {value}))")


def ask_category_questions(env, category):
    """Ask only the questions relevant to the chosen category, walking
    the SAME branch order as the matching rules in the .clp file, and
    assert each answer as an (answer (topic ...) (value ...)) fact.
    Returns False if the user should restart with a different category.
    """

    if category == "A":
        cable = ask_yes_no("Is the power cable connected?")
        assert_answer(env, "power-cable-connected", cable)
        if cable == "yes":
            outlet = ask_yes_no("Does the electrical outlet / power strip work?")
            assert_answer(env, "outlet-working", outlet)
            if outlet == "yes":
                laptop = ask_yes_no("Is this a laptop?")
                assert_answer(env, "is-laptop", laptop)
                if laptop == "yes":
                    adapter = ask_yes_no(
                        "Is the power adapter suspect (e.g. swapped, no change)?"
                    )
                    assert_answer(env, "adapter-suspect", adapter)
                response = ask_choice(
                    "Does the power button/indicator light respond at all?",
                    ["some", "none"],
                )
                assert_answer(env, "power-button-response", response.lower())

    elif category == "B":
        mon_on = ask_yes_no("Is the monitor powered on?")
        assert_answer(env, "monitor-powered-on", mon_on)
        if mon_on == "yes":
            mon_cable = ask_yes_no("Is the monitor's power cable loose?")
            assert_answer(env, "monitor-power-cable-loose", mon_cable)
            if mon_cable == "no":
                vid_cable = ask_yes_no("Is the video cable loose?")
                assert_answer(env, "video-cable-loose", vid_cable)
                if vid_cable == "no":
                    correct_input = ask_yes_no(
                        "Is the correct monitor input/source selected?"
                    )
                    assert_answer(env, "correct-input-selected", correct_input)
                    if correct_input == "yes":
                        alt_cable = ask_yes_no(
                            "Does the display work with another known-good video cable?"
                        )
                        assert_answer(env, "alt-video-cable-works", alt_cable)
                        if alt_cable == "no":
                            alt_monitor = ask_yes_no(
                                "Does another known-good monitor work?"
                            )
                            assert_answer(env, "alt-monitor-works", alt_monitor)
        beep = ask_yes_no("Are beep codes or diagnostic lights present?")
        assert_answer(env, "beep-codes-present", beep)

    elif category == "C":
        malware = ask_yes_no("Is there a malware / security alert?")
        assert_answer(env, "malware-alert", malware)
        if malware == "no":
            high_usage = ask_yes_no(
                "Is CPU/RAM usage high or are many applications open?"
            )
            assert_answer(env, "high-resource-usage", high_usage)
            low_disk = ask_yes_no("Is disk space low?")
            assert_answer(env, "low-disk-space", low_disk)
            many_startup = ask_yes_no("Are many startup applications running?")
            assert_answer(env, "many-startup-apps", many_startup)
            updates = ask_yes_no("Are there pending OS/software updates?")
            assert_answer(env, "pending-updates", updates)
            overheating = ask_yes_no("Is the computer overheating?")
            assert_answer(env, "overheating", overheating)
            if overheating == "yes":
                still_hot = ask_yes_no(
                    "Is it still overheating after improving ventilation?"
                )
                assert_answer(env, "still-overheating-after-vent", still_hot)

    elif category == "D":
        cable_loose = ask_yes_no("If wired, is the device cable loose?")
        assert_answer(env, "cable-loose", cable_loose)
        usb_faulty = ask_yes_no("Is the USB connection faulty?")
        assert_answer(env, "usb-port-faulty", usb_faulty)
        wireless = ask_yes_no("Is this a wireless keyboard/mouse?")
        assert_answer(env, "is-wireless", wireless)
        if wireless == "yes":
            batteries = ask_yes_no("Are the batteries low?")
            assert_answer(env, "batteries-low", batteries)
            switch_off = ask_yes_no("Is the wireless power switch off?")
            assert_answer(env, "wireless-switch-off", switch_off)
            receiver = ask_yes_no("Is the wireless receiver disconnected?")
            assert_answer(env, "receiver-disconnected", receiver)
        works_other = ask_yes_no("Does the device work on another computer?")
        assert_answer(env, "works-on-other-computer", works_other)

    elif category == "E":
        adapter_disabled = ask_yes_no("Is the Wi-Fi/Ethernet adapter disabled?")
        assert_answer(env, "adapter-disabled", adapter_disabled)
        if adapter_disabled == "no":
            wrong_net = ask_yes_no("Is the device connected to the wrong network?")
            assert_answer(env, "wrong-network", wrong_net)
            if wrong_net == "no":
                weak = ask_yes_no("Is the Wi-Fi signal weak?")
                assert_answer(env, "weak-signal", weak)
                if weak == "yes":
                    many = ask_yes_no("Do many users experience weak signal?")
                    assert_answer(env, "many-users-weak-signal", many)
                else:
                    connected_no_net = ask_yes_no(
                        "Does it show 'connected' but with no internet access?"
                    )
                    assert_answer(env, "connected-no-internet", connected_no_net)
                    if connected_no_net == "yes":
                        other_no_net = ask_yes_no(
                            "Do other devices also have no internet?"
                        )
                        assert_answer(env, "other-devices-no-internet", other_no_net)
                        if other_no_net == "yes":
                            restart_fix = ask_yes_no(
                                "After restarting the router/modem (if authorized), "
                                "did internet return?"
                            )
                            assert_answer(env, "router-restart-fixed", restart_fix)
                        else:
                            dev_fix = ask_yes_no(
                                "After checking this device's IP/DNS/network "
                                "settings, is it fixed?"
                            )
                            assert_answer(
                                env, "device-network-fix-worked", dev_fix
                            )
                    router_off = ask_yes_no("Is the router's power light off?")
                    assert_answer(env, "router-power-light-off", router_off)
                    if router_off == "yes":
                        restored = ask_yes_no(
                            "After checking cable/adapter/outlet, is router "
                            "power restored?"
                        )
                        assert_answer(env, "router-power-restored", restored)

    elif category == "F":
        app_outdated = ask_yes_no("Is the application outdated?")
        assert_answer(env, "app-outdated", app_outdated)
        if app_outdated == "no":
            os_outdated = ask_yes_no("Is the operating system outdated?")
            assert_answer(env, "os-outdated", os_outdated)
            if os_outdated == "no":
                low_res = ask_yes_no("Is memory or disk space insufficient?")
                assert_answer(env, "low-memory-disk", low_res)
                if low_res == "no":
                    repair = ask_yes_no(
                        "Is an application repair/reset option available?"
                    )
                    assert_answer(env, "repair-available", repair)
                    if repair == "yes":
                        still_crash = ask_yes_no(
                            "Does the application still crash after repair/reset?"
                        )
                        assert_answer(
                            env, "still-crashes-after-repair", still_crash
                        )
                        if still_crash == "yes":
                            reinstall = ask_yes_no(
                                "Is reinstalling the application allowed by policy?"
                            )
                            assert_answer(env, "reinstall-allowed", reinstall)
                            if reinstall == "yes":
                                still_fails = ask_yes_no(
                                    "Does it still fail after reinstalling?"
                                )
                                assert_answer(
                                    env, "still-fails-after-reinstall", still_fails
                                )

    elif category == "G":
        off = ask_yes_no("Is the printer powered off?")
        assert_answer(env, "printer-off", off)
        if off == "no":
            offline = ask_yes_no("Is the printer offline?")
            assert_answer(env, "printer-offline", offline)
        paper_empty = ask_yes_no("Is the paper tray empty?")
        assert_answer(env, "paper-empty", paper_empty)
        jam = ask_yes_no("Is there a paper jam?")
        assert_answer(env, "paper-jammed", jam)
        consumable = ask_yes_no("Is ink or toner empty?")
        assert_answer(env, "consumable-empty", consumable)
        queue = ask_yes_no("Does the print queue contain stuck jobs?")
        assert_answer(env, "queue-stuck", queue)
        wrong_printer = ask_yes_no("Is the wrong printer selected?")
        assert_answer(env, "wrong-printer-selected", wrong_printer)
        not_detected = ask_yes_no("Is the printer not being detected?")
        assert_answer(env, "printer-not-detected", not_detected)
        if not_detected == "yes":
            other_pc = ask_yes_no("Can another computer detect the printer?")
            assert_answer(env, "detected-by-other-computer", other_pc)
        quality = ask_yes_no("Is print quality poor?")
        assert_answer(env, "print-quality-poor", quality)
        if quality == "yes":
            still_poor = ask_yes_no(
                "Is quality still poor after cleaning/calibration?"
            )
            assert_answer(env, "quality-after-cleaning-poor", still_poor)

    elif category == "H":
        security_h = ask_yes_no(
            "Is a security incident suspected for this account issue?"
        )
        assert_answer(env, "security-incident-suspected", security_h)
        if security_h == "no":
            admin_req = ask_yes_no(
                "Is the account disabled or does this require administrator "
                "privileges?"
            )
            assert_answer(env, "account-disabled-or-admin-required", admin_req)
            if admin_req == "no":
                verified = ask_yes_no("Can the user's identity be verified?")
                assert_answer(env, "identity-verified", verified)
                if verified == "yes":
                    self_service = ask_yes_no(
                        "Is self-service password reset available?"
                    )
                    assert_answer(env, "self-service-available", self_service)
                    locked = ask_yes_no(
                        "Is the account locked (rather than just a forgotten "
                        "password)?"
                    )
                    assert_answer(env, "account-locked", locked)
        repeated = ask_yes_no("Does the account repeatedly become locked?")
        assert_answer(env, "repeatedly-locked", repeated)

    elif category == "I":
        classifiable = ask_yes_no(
            "On reflection, could this problem actually fit one of "
            "categories A-H?"
        )
        if classifiable == "yes":
            print("  -> Please restart and select the matching category (A-H).")
            return False
        level1 = ask_yes_no(
            "Is there a standard Level-1 troubleshooting step available?"
        )
        assert_answer(env, "level1-available", level1)
        if level1 == "yes":
            resolved = ask_yes_no("Did that Level-1 step resolve the problem?")
            assert_answer(env, "resolved-after-level1", resolved)

    return True


# ----------------------------------------------------------------------
# OUTPUT: read back CLIPS facts and print the ticket
# ----------------------------------------------------------------------

def get_facts_by_template(env, template_name):
    return [f for f in env.facts() if f.template.name == template_name]


def print_report(env):
    print("\n" + "=" * 60)
    print("TICKET REPORT")
    print("=" * 60)

    logs = get_facts_by_template(env, "action-log")
    if logs:
        print("\n-- Troubleshooting trace --")
        for f in sorted(logs, key=lambda x: x["step"]):
            print(f"  Step {f['step']}: {f['action']}")

    for d in get_facts_by_template(env, "diagnosis"):
        print("\n-- Diagnosis --")
        print(f"  Root cause             : {d['root-cause']}")
        print(f"  Resolved automatically  : {d['resolved']}")

    for e in get_facts_by_template(env, "escalation"):
        print("\n-- Escalation --")
        print(f"  Escalated to : {e['target']}")
        print(f"  Reason       : {e['reason']}")
        print(f"  Priority     : {e['priority']}")

    tickets = get_facts_by_template(env, "ticket")
    for t in tickets:
        print("\n-- Ticket --")
        print(f"  Status     : {t['status']}")
        print(f"  Priority   : {t['priority']}")
        print(f"  Root cause : {t['root-cause']}")
        print(f"  Solution   : {t['solution']}")

    if not tickets:
        print("\n  (No ticket fact was produced - check the rule base.)")

    print("\n" + "=" * 60)


# ----------------------------------------------------------------------
# MAIN DRIVER
# ----------------------------------------------------------------------

def main():
    env = clips.Environment()
    env.load(CLP_FILE)
    env.reset()

    print("IT SUPPORT EXPERT SYSTEM")
    print("(CLIPS decision engine + Python I/O layer)")

    collect_basic_info(env)
    is_critical = collect_critical_flags(env)

    if not is_critical:
        category = choose_category()
        env.assert_string(f"(category (code {category}))")
        proceed = ask_category_questions(env, category)
        if not proceed:
            print("\nPlease re-run the tool and pick the matching category.")
            return

    env.run()
    print_report(env)


if __name__ == "__main__":
    main()
