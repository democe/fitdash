#!/usr/bin/env python3
"""Config read/write helper for FitDash Quickshell widget."""
import json
import pathlib
import sys

CONFIG_PATH = pathlib.Path.home() / ".config" / "fitdash" / "config.json"


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    if sys.argv[1] == "read":
        if CONFIG_PATH.exists():
            # Print without trailing newline so SplitParser gets the exact content
            print(CONFIG_PATH.read_text(), end="")
        else:
            print("{}", end="")

    elif sys.argv[1] == "write":
        if len(sys.argv) < 3:
            sys.exit(1)
        try:
            data = json.loads(sys.argv[2])
        except json.JSONDecodeError as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_PATH.write_text(json.dumps(data, indent=2))

    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
