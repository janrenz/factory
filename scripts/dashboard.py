#!/usr/bin/env python3
"""Serve the factory board for the current repo.

The board page ships with the factory; the jobs live in the repo. This serves
/ → dashboard.html from the factory and /jobs/… from <repo>/factory/jobs/
(with directory listings, which the board reads to find the jobs).
Usage:  python3 <factory>/scripts/dashboard.py [port]   (default 8000)
"""
import http.server, os, subprocess, sys
from functools import partial

HOME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
JOBS = os.path.join(REPO, "factory", "jobs")


class Handler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        clean = path.split("?", 1)[0].split("#", 1)[0]
        if clean in ("/", "/dashboard.html"):
            return os.path.join(HOME, "dashboard", "dashboard.html")
        if clean == "/jobs" or clean.startswith("/jobs/"):
            rel = clean[len("/jobs"):].lstrip("/")
            target = os.path.realpath(os.path.join(JOBS, rel))
            if target == os.path.realpath(JOBS) or target.startswith(os.path.realpath(JOBS) + os.sep):
                return target
        return os.path.join(HOME, "dashboard", "404")

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=HOME))
    print(f"factory board for {REPO}: http://localhost:{port}/")
    srv.serve_forever()
