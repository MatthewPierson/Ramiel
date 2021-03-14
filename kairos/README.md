kairos
======
kairos is a 64-bit iOS boot image patcher written in C.

Patches include:
* RSA signature check removal
* boot-arg modification
* enabling of kernel debug
* command handler modification
* NVRAM unlock

Why?
----
I needed a C-based 64-bit iOS boot image patcher that worked with iOS 13.

Building
--------
	make

Example usage
-------------
	./kairos iBEC.dec iBEC.patched -n -b "-v debug=0x09" -c "go" 0x830000300
Note: the input boot image file must be decrypted and unpacked

Credits
-------
* [xerub](https://twitter.com/xerub)/[Pwn20wnd](https://twitter.com/Pwn20wnd) for patchfinder64
* [tihmstar](https://twitter.com/tihmstar) for code, inspiration, and patch methods
* [iH8sn0w](https://twitter.com/iH8sn0w) for code