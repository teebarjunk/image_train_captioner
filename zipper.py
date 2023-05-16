# Handles zipping files in a directory to a zip file.
import argparse
import sys
import shutil
from pathlib import Path
from zipfile import ZipFile
import tempfile

def read(path):
    if not path.exists():
        return ""
    
    with open(path, "r") as f:
        text = f.read()
    return text

def write(path, content=""):
    with open(path, "w") as f:
        f.write(content)

def zipper(args):
    tempdir = tempfile.mkdtemp()
    zipname = args.name
    if not zipname.endswith(".zip"):
        zipname += ".zip"
    try:
        with ZipFile(zipname, mode="w") as zf:
            for path in Path(args.dir).iterdir():
                if path.suffix in (".jpg", ".jpeg", ".png"):
                    # Save image.
                    if args.images:
                        zf.write(path, path.name)
                    
                    # Save caption.
                    if args.captions:
                        tokens = read(path.with_suffix(".caption")).split(",")
                        tokens = tokens + read(path.with_suffix(".txt")).split(",")
                        # Clean edges.
                        tokens = [x.strip() for x in tokens]
                        # Remove empty.
                        tokens = [x for x in tokens if x.strip() != ""]
                        # Convert to string.
                        tokens = ",".join(tokens)
                        # Write to temp file.
                        cap_name = path.stem + ".caption"
                        cap_path = Path(tempdir) / cap_name 
                        write(cap_path, tokens)
                        # Write to zip.
                        zf.write(cap_path, cap_name)
    finally:
        shutil.rmtree(tempdir)
    print(f"Saved zip to: {zipname}")


parser = argparse.ArgumentParser("zipper")
parser.add_argument("dir", nargs="?", help="directory with images and captions", type=str)
parser.add_argument("--captions", help="add captions?", action='store_true')
parser.add_argument("--images", help="add images?", action='store_true')
parser.add_argument("--name", help="name of zipfile", type=str, default="zipfile")
args = parser.parse_args()

if args.captions or args.images:
    zipper(args)
else:
    parser.print_usage()
