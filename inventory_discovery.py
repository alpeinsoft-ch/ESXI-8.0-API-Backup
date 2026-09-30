#!/usr/bin/env python3
"""Read-only inventory discovery wrapper.

Default behavior prints only the configured target VM. Use --show-all only
when a full inventory printout is explicitly needed for diagnostics.
"""

import sys

from safe_esxi_backup import main


if __name__ == "__main__":
    raise SystemExit(main(["inventory", *sys.argv[1:]]))
