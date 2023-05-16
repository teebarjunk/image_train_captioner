import sys, os, json
from pathlib import Path
info = {}
for path in Path(sys.argv[1]).iterdir():
    if path.suffix in (".png", ".jpg", ".jpeg"):
        (mode, ino, dev, nlink, uid, gid, size, atime, mtime, ctime) = path.stat()
        
        cappath = path.with_suffix(".caption")
        caption = ""
        if cappath.exists():
            with open(cappath, "r") as f:
                caption = f.read()
        
        # Estimate tokens.
        tokens = 0
        for t in [x.strip() for x in caption.split(",")]:
            tokens += len([x for x in t.split(" ")])
        
        info[str(path)] = {
            "path": str(path),      # Path to image from directory.
            "mtime": mtime,         # Last modified at.
            "ctime": ctime,         # Creation time.
            "bytes": size,          # Size of image in bytes.
            "caption": caption,     # Current caption, in temp memory.
            "unsaved": False,       # Caption was changed but not written to disk.
            "tokens": tokens        # Number of estimated tokens.
        }

# Write to file.
with open("tempdata.json", "w") as f:
    f.write(json.dumps(info))

print("Wrote to tempdata.json")
