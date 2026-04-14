#!/usr/bin/env python3
"""Interactive .anim file previewer with frame-by-frame playback."""

import curses
import os
import sys
import time


def load_anim(path):
    with open(path) as f:
        lines = [l.rstrip("\n") for l in f.readlines()]
    w = int(lines[0].split("=")[1])
    frames = []
    for line in lines[1:]:
        if not line.strip():
            continue
        parts = line.split("|")
        if len(parts) == 3:
            frames.append(parts)
        else:
            frames.append([line, "", ""])
    return w, frames


def render_frame(stdscr, w, frame, idx, total, playing, fps, path):
    stdscr.erase()
    h, scrw = stdscr.getmaxyx()

    # Title
    title = f" {os.path.basename(path)} "
    stdscr.attron(curses.A_BOLD)
    stdscr.addstr(0, 0, title.center(scrw, "─")[: scrw - 1])
    stdscr.attroff(curses.A_BOLD)

    # Frame content - pad each line to W
    L1 = frame[0].ljust(w) if len(frame) > 0 else " " * w
    L2 = frame[1].ljust(w) if len(frame) > 1 else " " * w
    L3 = frame[2].ljust(w) if len(frame) > 2 else " " * w

    # Simulated info column
    info1 = "[model-name] dir"
    info2 = "####------ 40%"

    y = 2
    # Draw cat + info (like real statusline)
    stdscr.addstr(y, 2, L1)
    stdscr.addstr(y, 2 + w + 1, info1)
    stdscr.addstr(y + 1, 2, L2)
    stdscr.addstr(y + 1, 2 + w + 1, info2)
    stdscr.addstr(y + 2, 2, L3)

    # Alignment ruler
    y += 4
    stdscr.attron(curses.color_pair(2))
    ruler = ":" + "." * (w - 1) + "|"
    stdscr.addstr(y, 2, ruler[: scrw - 3])
    stdscr.attroff(curses.color_pair(2))
    stdscr.addstr(y, 2 + w + 1, f"<-- W={w}", curses.color_pair(2))

    # Frame indicator
    y += 2
    stdscr.attron(curses.A_BOLD)
    stdscr.addstr(y, 2, f"Frame {idx + 1}/{total}")
    stdscr.attroff(curses.A_BOLD)

    # Frame bar
    y += 1
    bar = ""
    for i in range(total):
        if i == idx:
            bar += "█"
        else:
            bar += "░"
    stdscr.addstr(y, 2, bar[: scrw - 3])

    # Raw line content
    y += 2
    stdscr.addstr(y, 2, "Raw:", curses.A_DIM)
    y += 1
    raw = "|".join(frame)
    stdscr.addstr(y, 2, raw[: scrw - 3], curses.A_DIM)

    # Char count per segment
    y += 1
    lens = f"L1={len(frame[0])}  L2={len(frame[1])}  L3={len(frame[2])}"
    stdscr.addstr(y, 2, lens, curses.A_DIM)

    # Controls
    y = h - 3
    mode = f"▶ PLAY {fps}fps" if playing else "⏸ PAUSE"
    stdscr.attron(curses.color_pair(1))
    controls = f" {mode}  |  ←→ step  |  SPACE play/pause  |  +/- speed  |  q quit "
    stdscr.addstr(y, 0, controls.center(scrw)[: scrw - 1])
    stdscr.attroff(curses.color_pair(1))

    stdscr.refresh()


def main(stdscr, path):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
    curses.init_pair(2, curses.COLOR_YELLOW, -1)

    w, frames = load_anim(path)
    total = len(frames)
    idx = 0
    playing = False
    fps = 3
    last_tick = 0

    stdscr.timeout(50)  # 50ms poll

    while True:
        now = time.time()

        if playing and now - last_tick >= 1.0 / fps:
            idx = (idx + 1) % total
            last_tick = now

        render_frame(stdscr, w, frames[idx], idx, total, playing, fps, path)

        key = stdscr.getch()
        if key == ord("q") or key == 27:  # q or ESC
            break
        elif key == ord(" "):
            playing = not playing
            last_tick = now
        elif key == curses.KEY_RIGHT or key == ord("l"):
            playing = False
            idx = (idx + 1) % total
        elif key == curses.KEY_LEFT or key == ord("h"):
            playing = False
            idx = (idx - 1) % total
        elif key == ord("+") or key == ord("="):
            fps = min(fps + 1, 30)
        elif key == ord("-") or key == ord("_"):
            fps = max(fps - 1, 1)
        elif key == curses.KEY_HOME or key == ord("0"):
            idx = 0
            playing = False
        elif key == curses.KEY_END or key == ord("$"):
            idx = total - 1
            playing = False
        elif key == ord("r"):
            # Reload file
            w, frames = load_anim(path)
            total = len(frames)
            idx = idx % total


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file.anim>")
        print(f"       {sys.argv[0]} calm|active|panic")
        sys.exit(1)

    arg = sys.argv[1]
    # Allow shorthand: just state name
    if not os.path.exists(arg) and not arg.endswith(".anim"):
        candidate = os.path.expanduser(f"~/.claude/pet/anims/{arg}.anim")
        if os.path.exists(candidate):
            arg = candidate

    if not os.path.exists(arg):
        print(f"File not found: {arg}")
        sys.exit(1)

    curses.wrapper(main, arg)
