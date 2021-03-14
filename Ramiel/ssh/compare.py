# Copyright (c) 2020, @mcg29_
# Modified from https://github.com/dualbootfun/dualbootfun.github.io/blob/master/source/compareFiles.py

#!/usr/local/bin/python3

import os
import sys
import shutil

if __name__ == "__main__":
    args = sys.argv
    if len(args) < 3:
        print("Usage: kcache.raw kcache.patched")
        sys.exit(0)
    patched = open(args[2], "rb").read()
    original = open(args[1], "rb").read()
    test1 = open(args[2], "rb").read(28)
    test2 = open(args[1], "rb").read(28)
    lenP = len(patched)
    lenO = len(original)
    if test1 != test2 or lenP != lenO:
        # A10 kernels seem to not fully work with Kernel64Patcher
        # The start of the file is stripped, can be grabbed from raw kernel and placed back in
        raw = open(args[1], "rb")
        # CAFEBABE 00000001 0100000C 00000000 00004000 02319678 0000000E
        fix = b"\xca\xfe\xba\xbe\x00\x00\x00\x01\x01\x00\x00\x0c\x00\x00\x00\x00\x00\x00\x40\x00\x02\x31\x96\x78\x00\x00\x00\x0e"
        testPatched = open(f"{args[2]}.new", "w+b")

        testPatched.write(test2 + patched)

        testPatched.close()

        os.remove(args[2])
        shutil.move(f"{args[2]}.new", args[2])
        
    patched = open(args[2], "rb").read()
    original = open(args[1], "rb").read()
    lenP = len(patched)
    lenO = len(original)
    if lenP != lenO:
        print("Starting")
        # CAFEBABE 00000001 0100000C 00000000 00004000 02319678 0000000E
        fix = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        testPatched = open(f"{args[2]}", "w+b")
        testPatched.seek(41020239)
        testPatched.write(fix)

        testPatched.close()

        #os.remove(args[2])
        #shutil.move(f"{args[2]}", args[2])
        print("done")
        
    diff = []
    for i in range(lenO):
        originalByte = original[i]
        patchedByte = patched[i]
        if originalByte != patchedByte:
            diff.append([hex(i),hex(originalByte), hex(patchedByte)])
    diffFile = open('/tmp/kc.bpatch', 'w+')
    diffFile.write('#AMFI\n\n')
    for d in diff:
        data = str(d[0]) + " " + (str(d[1])) + " " + (str(d[2]))
        diffFile.write(data+ '\n')
        print(data)
