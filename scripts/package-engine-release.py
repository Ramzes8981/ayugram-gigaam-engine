#!/usr/bin/env python3
"""Create deterministic, pin-able release asset from verified Actions artifact."""
import hashlib
import pathlib
import re
import sys
import zipfile

REQUIRED = ('libggml-base.so', 'libggml-cpu.so', 'libggml.so', 'libtranscribe.so', 'SHA256SUMS', 'VERSION.txt')
COMMIT = '95d82e5134fba4b18ad6a46f3baf950f53bcfc3b'

def package(root, out):
    root = pathlib.Path(root)
    out = pathlib.Path(out)
    present = sorted(p.name for p in root.iterdir() if p.is_file())
    if present != sorted(REQUIRED):
        raise ValueError(f'Unexpected build files: {present}')
    checksums = {}
    for ln in (root/'SHA256SUMS').read_text('ascii').splitlines():
        m = re.fullmatch(r'([0-9a-f]{64})\s+\*?(?:\./)?(lib[^/]+\.so)', ln)
        if not m or m[2] in checksums:
            raise ValueError('Bad SHA256SUMS')
        checksums[m[2]] = m[1]
    if set(checksums) != {x for x in REQUIRED if x.endswith('.so')}:
        raise ValueError('Incomplete SHA256SUMS')
    for name, digest in checksums.items():
        content = (root/name).read_bytes()
        if hashlib.sha256(content).hexdigest() != digest:
            raise ValueError(f'Bad digest {name}')
        if not (content[:4] == b'\x7fELF' and content[4] == 2 and content[5] == 1 and content[18:20] == b'\xb7\0'):
            raise ValueError(f'Not aarch64 ELF {name}')
    version=(root/'VERSION.txt').read_text('ascii')
    if COMMIT not in version or 'arm64-v8a' not in version:
        raise ValueError('Wrong build source')
    out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as zf:
        for name in sorted(REQUIRED):
            zi=zipfile.ZipInfo(name,(2026, 1, 1, 0, 0, 0))
            zi.compress_type=zipfile.ZIP_DEFLATED
            zi.create_system=3
            zi.external_attr=(0o100644 << 16)
            zf.writestr(zi,(root/name).read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    digest=hashlib.sha256(out.read_bytes()).hexdigest()
    (out.parent/(out.name+'.sha256')).write_text(f'{digest}  {out.name}\n',encoding='ascii')
    print(digest, out.name)
    return digest

if __name__ == '__main__':
    if len(sys.argv)!=3:
        sys.exit('Usage: package-engine-release.py INPUT_DIR OUTPUT_ZIP')
    package(sys.argv[1],sys.argv[2])