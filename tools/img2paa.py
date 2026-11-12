# PNG/JPG -> DXT5 .paa (with alpha), mipmaps down to 4x4. Usage: img2paa.py in.png out.paa [size] [--keyout-white]
import sys, struct, numpy as np
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else None
im = Image.open(src).convert('RGBA')
if '--keyout-white' in sys.argv:
    # flood-fill the near-white background from the borders -> transparent, soft edge
    from collections import deque
    a = np.array(im); h, w = a.shape[:2]
    white = (a[:,:,0] > 235) & (a[:,:,1] > 235) & (a[:,:,2] > 235)
    bg = np.zeros((h, w), bool); q = deque()
    for x in range(w):
        for y in (0, h-1):
            if white[y,x] and not bg[y,x]: bg[y,x] = True; q.append((y,x))
    for y in range(h):
        for x in (0, w-1):
            if white[y,x] and not bg[y,x]: bg[y,x] = True; q.append((y,x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny, nx = y+dy, x+dx
            if 0 <= ny < h and 0 <= nx < w and white[ny,nx] and not bg[ny,nx]: bg[ny,nx] = True; q.append((ny,nx))
    a[bg, 3] = 0
    im = Image.fromarray(a)
if size: im = im.resize((size, size), Image.LANCZOS)
im.save(dst.replace('.paa', '_preview.png'))
def rgb565(c): return ((int(c[0]) >> 3) << 11) | ((int(c[1]) >> 2) << 5) | (int(c[2]) >> 3)
def un565(v): return np.array([((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31], float)
def dxt5(img):
    a = np.array(img).astype(np.int32); h, w = a.shape[:2]; out = bytearray()
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            blk = a[by:by+4, bx:bx+4].reshape(16, 4)
            al = blk[:,3]; mx, mn = int(al.max()), int(al.min())
            if mx == mn: out += bytes([mx, mn]) + b'\0'*6
            else:
                pal = np.array([mx, mn] + [((7-i)*mx + i*mn)//7 for i in range(1,7)])
                idx = np.abs(al[:,None] - pal[None,:]).argmin(1); bits = 0
                for i, k in enumerate(idx): bits |= int(k) << (3*i)
                out += bytes([mx, mn]) + bits.to_bytes(6, 'little')
            rgb = blk[:,:3].astype(float)
            c0 = rgb565(rgb.max(0)); c1 = rgb565(rgb.min(0))
            if c0 < c1: c0, c1 = c1, c0
            if c0 == c1:
                out += struct.pack('<HHI', c0, c1, 0); continue
            e0, e1 = un565(c0), un565(c1)
            pal = np.array([e0, e1, (2*e0+e1)/3, (e0+2*e1)/3])
            idx = ((rgb[:,None,:] - pal[None,:,:])**2).sum(2).argmin(1); bits = 0
            for i, k in enumerate(idx): bits |= int(k) << (2*i)
            out += struct.pack('<HHI', c0, c1, bits)
    return bytes(out)
def tagg(name, data): return b'GGAT' + name + struct.pack('<I', len(data)) + data
levels = []; cur = im
while min(cur.size) >= 4: levels.append(cur); cur = cur.resize((cur.size[0]//2, cur.size[1]//2), Image.LANCZOS)
avg = np.array(levels[-1]).reshape(-1,4).mean(0).astype(int)
head = struct.pack('<H', 0xFF05)
t = tagg(b'CGVA', bytes([avg[2], avg[1], avg[0], avg[3]])) + tagg(b'CXAM', bytes([255,255,255,255])) + tagg(b'GALF', struct.pack('<I', 1))
pos = len(head) + len(t) + len(tagg(b'SFFO', b'\0'*64)) + 2
mips = b''; offs = []
for l in levels:
    d = dxt5(l); offs.append(pos + len(mips))
    mips += struct.pack('<HH', l.size[0], l.size[1]) + len(d).to_bytes(3, 'little') + d
offs += [0] * (16 - len(offs))
open(dst, 'wb').write(head + t + tagg(b'SFFO', struct.pack('<16I', *offs[:16])) + struct.pack('<H', 0) + mips + b'\0'*6)
print(dst, len(levels), 'mipmaps')
