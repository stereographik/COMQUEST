# writes a white radial soft-dot as a DXT5 .paa (alpha only varies) + a .png preview
import struct, sys, math, zlib
def alpha_img(n):
    R=n/2.0; a=[]
    for y in range(n):
        row=[]
        for x in range(n):
            r=math.hypot(x+0.5-R,y+0.5-R)/R
            v=max(0.0,1-r*r)**2
            row.append(int(round(255*v)))
        a.append(row)
    return a
def down(a):
    n=len(a)//2
    return [[(a[2*y][2*x]+a[2*y][2*x+1]+a[2*y+1][2*x]+a[2*y+1][2*x+1]+2)//4 for x in range(n)] for y in range(n)]
def ablock(px):
    mx,mn=max(px),min(px)
    if mx==mn: return bytes([mx,mn])+b'\0'*6
    pal=[mx,mn]+[((7-i)*mx+i*mn)//7 for i in range(1,7)]
    bits=0
    for i,p in enumerate(px):
        k=min(range(8),key=lambda j:abs(pal[j]-p))
        bits|=k<<(3*i)
    return bytes([mx,mn])+bits.to_bytes(6,'little')
def dxt5(a):
    n=len(a); out=bytearray()
    for by in range(0,n,4):
        for bx in range(0,n,4):
            px=[a[by+j][bx+i] for j in range(4) for i in range(4)]
            out+=ablock(px)+struct.pack('<HHI',0xFFFF,0xFFFF,0)
    return bytes(out)
def tagg(name,data): return b'GGAT'+name+struct.pack('<I',len(data))+data
n=int(sys.argv[2]) if len(sys.argv)>2 else 128
levels=[]; a=alpha_img(n)
while len(a)>=4: levels.append(a); a=down(a)
avg=sum(sum(r) for r in levels[0])//(n*n)
head=struct.pack('<H',0xFF05)
t_avg=tagg(b'CGVA',bytes([255,255,255,avg]))   # BGRA
t_max=tagg(b'CXAM',bytes([255,255,255,255]))
t_flag=tagg(b'GALF',struct.pack('<I',1))
offs_len=len(tagg(b'SFFO',b'\0'*64))
pos=len(head)+len(t_avg)+len(t_max)+len(t_flag)+offs_len+2
mips=b''; offs=[]
for l in levels:
    d=dxt5(l); offs.append(pos+len(mips))
    mips+=struct.pack('<HH',len(l),len(l))+len(d).to_bytes(3,'little')+d
offs+= [0]*(16-len(offs))
data=head+t_avg+t_max+t_flag+tagg(b'SFFO',struct.pack('<16I',*offs))+struct.pack('<H',0)+mips+b'\0'*6
open(sys.argv[1],'wb').write(data)
# png preview (white + alpha)
def png(path,a):
    n=len(a); raw=b''.join(b'\0'+b''.join(bytes([255,255,255,v]) for v in r) for r in a)
    ch=lambda t,d: struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    open(path,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',n,n,8,6,0,0,0))+ch(b'IDAT',zlib.compress(raw))+ch(b'IEND',b''))
png(sys.argv[1].replace('.paa','.png'),levels[0])
print(len(data),'bytes,',len(levels),'mipmaps')
