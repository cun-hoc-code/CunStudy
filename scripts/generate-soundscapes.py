#!/usr/bin/env python3
"""Deterministic, original procedural ambient loops. No downloaded recordings."""
import math, random, struct, wave
from pathlib import Path
rate, seconds = 22050, 12
n=rate*seconds
root=Path(__file__).resolve().parents[1]/'Resources'/'Sounds';root.mkdir(exist_ok=True)
for name,seed in [('rain',31),('cafe',52),('white',77)]:
    rng=random.Random(seed);out=[];low=0
    for i in range(n):
        t=i/rate;noise=rng.uniform(-1,1);low=.985*low+.015*noise
        if name=='white': value=noise*.18
        elif name=='rain': value=(noise*.12+low*.75)*(0.78+.16*math.sin(2*math.pi*t/12))
        else: value=low*1.1+noise*.018+.008*math.sin(2*math.pi*110*t)*(1+math.sin(2*math.pi*t/4))
        out.append(value)
    # Equal-power crossfade tail into head eliminates loop-boundary clicks.
    fade=rate//4
    for i in range(fade):
        k=i/fade;out[i]=out[n-fade+i]*(1-k)+out[i]*k
    out=out[:-fade]
    with wave.open(str(root/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        f.writeframes(b''.join(struct.pack('<h',max(-32767,min(32767,int(x*32767)))) for x in out))
print('Created three original mono ambient loops.')
