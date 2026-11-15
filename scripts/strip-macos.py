"""Strip deployed Mach-O files before the final bundle signing pass."""

import concurrent.futures
import os
from pathlib import Path
import subprocess
import sys

# Read magic bytes directly: avoid spawning `file` once per bundle resource.
MACHO_MAGICS = {
    bytes.fromhex(value)
    for value in ("feedface", "cefaedfe", "feedfacf", "cffaedfe",
                  "cafebabe", "bebafeca", "cafebabf", "bfbafeca")
}


def strip_binary(path):
    subprocess.run(["strip", "-x", str(path)], check=True)


def main():
    binaries = []
    for directory, _, filenames in os.walk(sys.argv[1], followlinks=False):
        for filename in filenames:
            path = Path(directory, filename)
            if path.is_symlink():
                continue
            with path.open("rb") as source:
                if source.read(4) in MACHO_MAGICS:
                    binaries.append(path)
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 1) as pool:
        list(pool.map(strip_binary, binaries))
    print(f"Stripped {len(binaries)} Mach-O files")


if __name__ == "__main__":
    main()
