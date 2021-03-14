
#ifndef FileMDHash_h
#define FileMDHash_h

#include <stdio.h>

CFStringRef FileMD5HashCreateWithPath(CFStringRef filePath, size_t chunkSizeForReadingData);

#endif /* FileMDHash_h */
