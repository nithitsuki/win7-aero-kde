#!/usr/bin/env python3
"""Windows 7-style graphical installer for win7-aero-kde.

Runs the real install.sh and renders its progress as a Windows 7 setup screen:
segmented green bar, status text and a collapsible log.
"""

import os
import queue
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import tkinter as tk
from tkinter import messagebox, simpledialog
from tkinter import font as tkfont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INSTALL = os.path.join(ROOT, "install.sh")

BG = "#F0F0F0"
PANEL = "#FFFFFF"
INK = "#1B1B1B"
MUTED = "#5F5F5F"
LINE = "#3C8BD9"
GREEN = "#2FA84F"
GREEN_DIM = "#8CCB9B"
TROUGH = "#C9C9C9"
BORDER = "#A0A0A0"

SEGMENTS = 32
BAR_W = 464
BAR_H = 22


def pick_font(root, candidates):
    families = set(tkfont.families(root))
    for name in candidates:
        if name in families:
            return name
    return "DejaVu Sans"


class Installer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Windows 7 Setup")
        self.geometry("520x400")
        self.resizable(False, False)
        self.configure(bg=BG)
        

        self.body_font = pick_font(self, ["Segoe UI", "DejaVu Sans"])
        self.light_font = pick_font(self, ["Segoe UI Light", "Segoe UI", "DejaVu Sans"])

        self.proc = None
        self.queue = queue.Queue()
        self.password_file = None
        self.tmpdir = None
        self.details_open = False
        self.running = False
        self.cancelled = False
        self.keepalive = None
        self.games = tk.BooleanVar(
            value=os.environ.get("WIN7_GUI_SKIP_GAMES") != "1")

        self._build()
        self.protocol("WM_DELETE_WINDOW", self.on_close)
        self.after(80, self.poll)

    # ---------------------------------------------------------------- layout

    def _build(self):
        header = tk.Canvas(self, height=104, bg=PANEL, highlightthickness=0)
        header.pack(fill="x")
        for y in range(104):
            t = y / 103.0
            r = int(236 + (255 - 236) * t)
            g = int(246 + (255 - 246) * t)
            b = int(253 + (255 - 253) * t)
            header.create_line(0, y, 520, y, fill=f"#{r:02x}{g:02x}{b:02x}")
        header.create_text(28, 38, anchor="w", text="Windows 7",
                           font=(self.light_font, 24), fill=INK)
        header.create_text(31, 84, anchor="w", text="Setup",
                           font=(self.body_font, 11), fill=MUTED)
        tk.Frame(self, bg=LINE, height=2).pack(fill="x")

        self.content = tk.Frame(self, bg=BG)
        self.content.pack(fill="both", expand=True, padx=28, pady=16)

        self.status = tk.Label(self.content, text="Welcome to Windows 7 Setup",
                               font=(self.body_font, 12), bg=BG, fg=INK, anchor="w")
        self.status.pack(fill="x")

        self.sub = tk.Label(self.content,
                            text="This will install the Windows 7 desktop on KDE Plasma.",
                            font=(self.body_font, 9), bg=BG, fg=MUTED,
                            anchor="w", justify="left", wraplength=460)
        self.sub.pack(fill="x", pady=(4, 14))

        self.bar = tk.Canvas(self.content, width=BAR_W, height=BAR_H,
                             bg=BG, highlightthickness=0)
        self.bar.pack(fill="x")
        self._draw_bar(0.0)

        self.games_check = tk.Checkbutton(
            self.content, text="Install the Windows 7 games",
            variable=self.games, bg=BG, fg=INK, activebackground=BG,
            selectcolor=PANEL, anchor="w", highlightthickness=0, bd=0,
            font=(self.body_font, 9))
        self.games_check.pack(fill="x", pady=(12, 0))

        self.details = tk.Text(self.content, height=7, bg=PANEL, fg="#333333",
                               relief="solid", bd=1, highlightthickness=0,
                               font=("DejaVu Sans Mono", 8), wrap="none")
        self.details.configure(state="disabled")

        footer = tk.Frame(self, bg=BG)
        footer.pack(side="bottom", fill="x", padx=24, pady=14)

        self.details_btn = tk.Button(footer, text="Details", width=9,
                                     command=self.toggle_details,
                                     font=(self.body_font, 9), relief="flat",
                                     bg=BG, activebackground=BG, fg=MUTED,
                                     bd=0, highlightthickness=0)
        self.details_btn.pack(side="left")

        self.cancel_btn = tk.Button(footer, text="Cancel", width=12,
                                    command=self.cancel, state="disabled",
                                    font=(self.body_font, 9))
        self.cancel_btn.pack(side="right", padx=(8, 0))

        self.install_btn = tk.Button(footer, text="Install now", width=14,
                                     command=self.start, default="active",
                                     font=(self.body_font, 9))
        self.install_btn.pack(side="right")

    def _draw_bar(self, fraction, current=False):
        self.bar.delete("all")
        gap = 2
        seg_w = (BAR_W - gap * (SEGMENTS - 1)) / SEGMENTS
        filled = int(round(fraction * SEGMENTS))
        for i in range(SEGMENTS):
            x0 = i * (seg_w + gap)
            x1 = x0 + seg_w
            if i < filled:
                colour = GREEN
            elif i == filled and current:
                colour = GREEN_DIM
            else:
                colour = TROUGH
            self.bar.create_rectangle(x0, 0, x1, BAR_H, fill=colour, outline="")
        self.bar.create_rectangle(0, 0, BAR_W - 1, BAR_H - 1,
                                  outline=BORDER, width=1)

    # ---------------------------------------------------------------- state

    def set_busy(self, busy):
        self.running = busy
        self.install_btn.configure(state="disabled" if busy else "normal")
        self.cancel_btn.configure(state="normal" if busy else "disabled")
        self.games_check.configure(state="disabled" if busy else "normal")

    def log(self, text):
        self.details.configure(state="normal")
        self.details.insert("end", text + "\n")
        # keep the widget bounded
        if int(self.details.index("end-1c").split(".")[0]) > 800:
            self.details.delete("1.0", "200.0")
        self.details.see("end")
        self.details.configure(state="disabled")

    def toggle_details(self):
        self.details_open = not self.details_open
        if self.details_open:
            self.details.pack(fill="both", expand=True, pady=(12, 0))
            self.geometry("520x520")
            self.details_btn.configure(text="Hide details")
        else:
            self.details.pack_forget()
            self.geometry("520x400")
            self.details_btn.configure(text="Details")

    # ---------------------------------------------------------------- sudo

    def prepare_sudo(self):
        """Cache sudo credentials once, without exposing the password.

        The password is used only by the askpass helper and deleted before the
        installer starts. The cached sudo timestamp is refreshed in the
        background, so build scripts run by the installer never see the secret.
        """
        try:
            if subprocess.run(["sudo", "-n", "true"], stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=10).returncode == 0:
                return dict(os.environ)
        except Exception:
            pass

        password = simpledialog.askstring(
            "Administrator", "Enter your password to continue:", show="*",
            parent=self)
        if not password:
            return None

        tmpdir = tempfile.mkdtemp(prefix="win7-installer-")
        os.chmod(tmpdir, 0o700)
        pwfile = os.path.join(tmpdir, "password")
        with open(pwfile, "w", encoding="utf-8") as f:
            f.write(password + "\n")
        os.chmod(pwfile, 0o600)
        askpass = os.path.join(tmpdir, "askpass")
        with open(askpass, "w", encoding="utf-8") as f:
            f.write('#!/bin/sh\ncat "$WIN7_ASKPASS_FILE"\n')
        os.chmod(askpass, 0o700)

        env = dict(os.environ)
        env["SUDO_ASKPASS"] = askpass
        env["WIN7_ASKPASS_FILE"] = pwfile
        ok = False
        try:
            result = subprocess.run(["sudo", "-A", "-v"], env=env,
                                    stdout=subprocess.DEVNULL,
                                    stderr=subprocess.PIPE, text=True,
                                    timeout=60)
            ok = result.returncode == 0
        except Exception:
            ok = False
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

        if not ok:
            messagebox.showerror("Administrator",
                                 "The password was not accepted.", parent=self)
            return None

        self.keepalive = threading.Event()
        threading.Thread(target=self._keepalive_loop, daemon=True).start()
        return dict(os.environ)

    def _keepalive_loop(self):
        while self.keepalive and not self.keepalive.wait(240):
            try:
                subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, timeout=30)
            except Exception:
                pass

    # ---------------------------------------------------------------- run

    def start(self):
        if self.running:
            return
        env = self.prepare_sudo()
        if env is None:
            return

        env["WIN7_PROGRESS"] = "1"
        args = ["bash", INSTALL]
        if not self.games.get():
            args.append("--skip-games")

        self.set_busy(True)
        self.install_btn.configure(text="Installing...")
        self.status.configure(text="Starting setup...")
        self.sub.configure(text="Please wait while Windows 7 Setup copies files and installs features.")
        self._draw_bar(0.0, current=True)
        self.log("Running: " + " ".join(args))

        self.proc = subprocess.Popen(
            args, cwd=ROOT, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, bufsize=1,
            start_new_session=True)
        threading.Thread(target=self._reader, daemon=True).start()

    def _reader(self):
        proc = self.proc
        for line in proc.stdout:
            self.queue.put(line.rstrip("\n"))
        proc.wait()
        self.queue.put(("__EXIT__", proc.returncode))

    def poll(self):
        try:
            while True:
                item = self.queue.get_nowait()
                if isinstance(item, tuple):
                    self.finish(item[1])
                else:
                    self.handle_line(item)
        except queue.Empty:
            pass
        self.after(80, self.poll)

    def handle_line(self, line):
        if line.startswith("@@STEP "):
            parts = line.split(" ", 3)
            if len(parts) == 4:
                _, n, total, label = parts
                try:
                    fraction = max(int(n) - 1, 0) / max(int(total), 1)
                except ValueError:
                    fraction = 0.0
                self._draw_bar(fraction, current=True)
                self.status.configure(text=label + "...")
                self.log(line)
            return
        if line.startswith("@@DONE"):
            self._draw_bar(1.0)
            return
        if line:
            self.log(line)

    def finish(self, code):
        self.cleanup()
        self.set_busy(False)
        self.proc = None
        if self.cancelled:
            self.status.configure(text="Setup canceled")
            self.sub.configure(text="Files already copied remain on disk. Run the "
                                    "uninstaller to remove them.")
            self.install_btn.configure(text="Close", command=self.destroy,
                                       state="normal")
            self.cancel_btn.configure(state="disabled")
            return
        if code == 0:
            self._draw_bar(1.0)
            self.status.configure(text="Setup complete")
            self.sub.configure(
                text="Windows 7 has been installed. Log out and choose the "
                     "AeroThemePlasma session.")
            self.install_btn.configure(text="Finish", command=self.destroy,
                                       state="normal")
            self.cancel_btn.configure(state="disabled")
            self.games_check.pack_forget()
        else:
            state = os.environ.get("XDG_DATA_HOME",
                                   os.path.expanduser("~/.local/share"))
            self.status.configure(text="Setup could not complete")
            self.sub.configure(text="Open Details for the failing step. The log "
                                    f"is in {state}/win7-aero/install.log.")
            self.install_btn.configure(text="Close", command=self.destroy,
                                       state="normal")
            self.cancel_btn.configure(state="disabled")
            if not self.details_open:
                self.toggle_details()

    def cancel(self):
        if not self.proc or self.cancelled:
            return
        if not messagebox.askyesno(
                "Cancel setup",
                "Cancel the installation? Files already copied will stay on "
                "disk; the uninstaller can remove them."):
            return
        self.cancelled = True
        self.status.configure(text="Canceling setup...")
        self.sub.configure(text="Waiting for the current step to stop.")
        self.cancel_btn.configure(state="disabled")
        self._terminate()

    def _terminate(self):
        proc = self.proc
        if not proc:
            return
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except ProcessLookupError:
            return

        def harder():
            for _ in range(10):
                time.sleep(0.5)
                if proc.poll() is not None:
                    return
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except ProcessLookupError:
                pass

        threading.Thread(target=harder, daemon=True).start()

    def cleanup(self):
        if self.keepalive:
            self.keepalive.set()
            self.keepalive = None

    def on_close(self):
        if self.running:
            if not messagebox.askyesno("Close setup",
                                       "Setup is running. Cancel it?"):
                return
            self.cancelled = True
            self._terminate()
        self.cleanup()
        self.destroy()


def main():
    if not os.path.isfile(INSTALL):
        print(f"install.sh not found next to {__file__}", file=sys.stderr)
        return 1
    if not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY"):
        print("No graphical session found; run ./install.sh instead.", file=sys.stderr)
        return 1
    app = Installer()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
