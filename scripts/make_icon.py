#!/usr/bin/env python3
"""Render the app's own vector leaf mark into an Apple app-icon asset catalog.
Uses only Python's standard library; the input artwork is the app's code-native
sprout motif, not an AI-generated image or a photo.
"""
from pathlib import Path
import json
import math
import struct
import zlib

root = Path(__file__).resolve().parents[1]
catalog = root / "Resources/Assets.xcassets/AppIcon.appiconset"
catalog.mkdir(parents=True, exist_ok=True)

def inside_poly(x, y, points):
    inside = False
    j = len(points) - 1
    for i, (xi, yi) in enumerate(points):
        xj, yj = points[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside

def curve(a, b, c):
    return [((1-t)**2*a[0]+2*(1-t)*t*b[0]+t*t*c[0], (1-t)**2*a[1]+2*(1-t)*t*b[1]+t*t*c[1]) for t in [i/40 for i in range(41)]]

left = curve((.50,.52),(.19,.54),(.23,.28)) + curve((.23,.28),(.51,.27),(.50,.52))
right = curve((.50,.48),(.51,.21),(.80,.23)) + curve((.80,.23),(.81,.50),(.50,.48))

def png(size):
    rows = bytearray()
    for py in range(size):
        rows.append(0)
        y = (py+.5)/size
        for px in range(size):
            x = (px+.5)/size
            color = (249, 245, 230)
            if .10 < x < .9 and .10 < y < .9:
                if abs((y-.14) % .09) < .0012: color = (231, 231, 210)
            # Hand-drawn notebook frame, stem, pot and two organic leaves.
            if .17 < x < .83 and (.145 < y < .153 or .846 < y < .854): color = (181, 184, 152)
            if .15 < y < .85 and (.145 < x < .153 or .847 < x < .855): color = (181, 184, 152)
            stem_x = .50 + .016*math.sin((y-.4)*8)
            if .4 < y < .72 and abs(x-stem_x) < .009: color = (67, 104, 64)
            if inside_poly(x,y,left): color = (161, 190, 130)
            if inside_poly(x,y,right): color = (91, 139, 81)
            if .66 < y < .78 and .35+(y-.66)*.4 < x < .65-(y-.66)*.4: color=(216, 150, 114)
            if .642 < y < .667 and .33 < x < .67: color=(190, 124, 93)
            rows.extend(color)
    def chunk(kind, data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(rows),9))+chunk(b'IEND',b'')

images=[]
for idiom, sizes in [('iphone',[(20,[2,3]),(29,[2,3]),(40,[2,3]),(60,[2,3])]),('ipad',[(20,[1,2]),(29,[1,2]),(40,[1,2]),(76,[1,2]),(83.5,[2])]),('ios-marketing',[(1024,[1])])]:
    for base, scales in sizes:
        for scale in scales:
            pixels=int(base*scale); name=f'icon-{pixels}.png'
            path=catalog/name
            if not path.exists(): path.write_bytes(png(pixels))
            images.append(dict(idiom=idiom,size=f'{base}x{base}',scale=f'{scale}x',filename=name))
(catalog/'Contents.json').write_text(json.dumps(dict(images=images,info=dict(version=1,author='xcode')),indent=2))
(catalog.parent/'Contents.json').write_text(json.dumps(dict(info=dict(version=1,author='xcode'))))
print('Generated RGB icons for iPhone, iPad and marketing (no alpha).')
