# ffmpeg-rt :: the release zips, one per target, from installed builds (dist/<arch>-<variant>):
#   ffmpeg-<version>-rt-<arch>/bin       the six DLLs and their PDBs, ffmpeg.exe and ffmpeg_g.pdb
#   ffmpeg-<version>-rt-<arch>/lib       the import libraries (.lib) and .def files
#   ffmpeg-<version>-rt-<arch>/include   the headers
#   ffmpeg-<version>-rt-<arch>/licenses  FFmpeg's, dav1d's and zlib's licence texts
#   ffmpeg-<version>-rt-<arch>/checks    the RT 8.1 checks of verify-build.sh, if present
#   ffmpeg-<version>-rt-<arch>/SHA256SUMS.txt
# plus <zip>.sha256 next to each zip.
# Usage: python -I scripts/package.py <deps folder> <out folder> <version> <arch>=<dist folder> [<arch>=<dist folder> ...]
import hashlib
import os
import shutil
import sys
import tarfile
import zipfile

deps, out, version = sys.argv[1:4]
# FFmpeg's from the pinned tarball itself (Kodi's patch 001 edits LICENSE.md in the patched tree)
LICENSES = {'FFmpeg-LICENSE.md': (f'ffmpeg-{version}.tar.xz', f'ffmpeg-{version}/LICENSE.md'),
            'FFmpeg-COPYING.LGPLv2.1': (f'ffmpeg-{version}.tar.xz', f'ffmpeg-{version}/COPYING.LGPLv2.1'),
            'dav1d-COPYING': (None, 'dav1d-1.5.3/COPYING'),
            'zlib-LICENSE': (None, 'zlib-1.3.2/LICENSE')}


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


os.makedirs(out, exist_ok=True)
for spec in sys.argv[4:]:
    arch, dist = spec.split('=', 1)
    top = f'ffmpeg-{version}-rt-{arch}'
    stage = os.path.join(out, top)
    if os.path.exists(stage):
        shutil.rmtree(stage)
    for n in sorted(os.listdir(os.path.join(dist, 'bin'))):
        src = os.path.join(dist, 'bin', n)
        if n.endswith('.lib'):
            sub = 'lib'
        elif n.endswith(('.dll', '.pdb', '.exe')):
            sub = 'bin'
        else:
            continue
        os.makedirs(os.path.join(stage, sub), exist_ok=True)
        shutil.copy2(src, os.path.join(stage, sub, n))
    for n in sorted(os.listdir(os.path.join(dist, 'lib'))):
        if n.endswith('.def'):
            shutil.copy2(os.path.join(dist, 'lib', n), os.path.join(stage, 'lib', n))
    shutil.copytree(os.path.join(dist, 'include'), os.path.join(stage, 'include'))
    if os.path.isdir(os.path.join(dist, 'checks')):
        shutil.copytree(os.path.join(dist, 'checks'), os.path.join(stage, 'checks'))
    os.makedirs(os.path.join(stage, 'licenses'))
    for dst, (tarball, member) in LICENSES.items():
        if tarball:
            with tarfile.open(os.path.join(deps, tarball)) as t:
                data = t.extractfile(member).read()
            with open(os.path.join(stage, 'licenses', dst), 'wb') as f:
                f.write(data)
        else:
            shutil.copy2(os.path.join(deps, member), os.path.join(stage, 'licenses', dst))
    files = []
    for root, _, names in os.walk(stage):
        for n in names:
            files.append(os.path.relpath(os.path.join(root, n), stage).replace(os.sep, '/'))
    files.sort()
    with open(os.path.join(stage, 'SHA256SUMS.txt'), 'w', encoding='ascii', newline='\r\n') as s:
        for rel in files:
            s.write(f'{sha256(os.path.join(stage, rel))}  {rel}\n')
    z = os.path.join(out, top + '.zip')
    if os.path.exists(z):
        os.remove(z)
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for rel in ['SHA256SUMS.txt'] + files:
            zf.write(os.path.join(stage, rel), f'{top}/{rel}')
    with zipfile.ZipFile(z) as zf:
        if zf.testzip():
            sys.exit(f'{z}: zip test failed')
    digest = sha256(z)
    with open(z + '.sha256', 'w', encoding='ascii', newline='\n') as s:
        s.write(f'{digest} *{os.path.basename(z)}\n')
    shutil.rmtree(stage)
    print(f'{z}: {len(files) + 1} files, {os.path.getsize(z)} bytes, sha256 {digest}')
