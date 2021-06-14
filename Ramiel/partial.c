/**
  * libpartialzip-1.0 - libpartialzip.c
  * Copyright (C) 2010 David Wang
  *
  * Modified by:
  * Copyright (C) 2010-2013 Joshua Hill
  *
  * This program is free software: you can redistribute it and/or modify
  * it under the terms of the GNU General Public License as published by
  * the Free Software Foundation, either version 3 of the License, or
  * (at your option) any later version.
  *
  * This program is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  * GNU General Public License for more details.
  *
  * You should have received a copy of the GNU General Public License
  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <libgen.h>

#include <zlib.h>
#include <curl/curl.h>

#ifdef __cplusplus
#define __STDC_FORMAT_MACROS
#include <inttypes.h>
#endif

#include <partial.h>

static size_t count = 0;
char endianness = IS_LITTLE_ENDIAN;

int partialzip_download_file(const char* url, const char* path, const char* output) {
    FILE* fd;
    partialzip_file_t* file;
    partialzip_t* info;
    unsigned int size;
    unsigned char* data;

    info = partialzip_open(url);
    if (!info) {
        printf("Cannot find %s\n", url);
        return -1;
    }

    file = partialzip_find_file(info, path);
    if (!file) {
        printf("Cannot find %s in %s\n", path, url);
        return -1;
    }

    data = partialzip_get_file(info, file);
    if(!data) {
        printf("Cannot get %s from %s\n", path, url);
        return -1;
    }
    size = file->size;

    fd = fopen(output, "wb");
    if(!fd) {
        printf("Cannot open file %s for output\n", output);
        return -1;
    }

    if(fwrite(data, 1, size, fd) != size) {
        printf("Unable to write entire file to output\n");
        fclose(fd);
        return -1;
    }

    fclose(fd);
    partialzip_close(info);
    free(data);
    return 0;
}

static size_t dummyReceive(void* data, size_t size, size_t nmemb, void* info) {
    return size * nmemb;
}

static size_t receiveCentralDirectoryEnd(void* data, size_t size, size_t nmemb, partialzip_t* info) {
    memcpy(info->centralDirectoryEnd + info->centralDirectoryEndRecvd, data, size * nmemb);
    info->centralDirectoryEndRecvd += size * nmemb;
    return size * nmemb;
}

static size_t receiveCentralDirectory(void* data, size_t size, size_t nmemb, partialzip_t* info) {
    memcpy(info->centralDirectory + info->centralDirectoryRecvd, data, size * nmemb);
    info->centralDirectoryRecvd += size * nmemb;
    return size * nmemb;
}

static size_t receiveData(void* data, size_t size, size_t nmemb, void** pFileData) {
    memcpy(pFileData[0], data, size * nmemb);
    pFileData[0] = ((char*)pFileData[0]) + (size * nmemb);
    partialzip_t* info = ((partialzip_t*)pFileData[1]);
    partialzip_file_t* file = ((partialzip_file_t*)pFileData[2]);
    size_t* progress = ((size_t*)pFileData[3]);

    if(progress) {
        count += size * nmemb;
        *progress += size * nmemb;
    }

    if(info && info->progressCallback && file) {
        *progress = ((double) count/ (double) file->compressedSize) * 100.0;
        info->progressCallback(info, file, *progress);
    }

    return size * nmemb;
}

static partialzip_file_t* flipFiles(partialzip_t* info)
{
    char* cur = info->centralDirectory;

    unsigned int i;
    for(i = 0; i < info->centralDirectoryDesc->CDEntries; i++)
    {
        partialzip_file_t* candidate = (partialzip_file_t*) cur;
        FLIPENDIANLE(candidate->signature);
        FLIPENDIANLE(candidate->version);
        FLIPENDIANLE(candidate->versionExtract);
        // FLIPENDIANLE(candidate->flags);
        FLIPENDIANLE(candidate->method);
        FLIPENDIANLE(candidate->modTime);
        FLIPENDIANLE(candidate->modDate);
        // FLIPENDIANLE(candidate->crc32);
        FLIPENDIANLE(candidate->compressedSize);
        FLIPENDIANLE(candidate->size);
        FLIPENDIANLE(candidate->lenFileName);
        FLIPENDIANLE(candidate->lenExtra);
        FLIPENDIANLE(candidate->lenComment);
        FLIPENDIANLE(candidate->diskStart);
        // FLIPENDIANLE(candidate->internalAttr);
        // FLIPENDIANLE(candidate->externalAttr);
        FLIPENDIANLE(candidate->offset);

        cur += sizeof(partialzip_file_t) + candidate->lenFileName + candidate->lenExtra + candidate->lenComment;
        return candidate;
    }
    return NULL;
}

partialzip_t* partialzip_open(const char* url)
{
    partialzip_t* info = (partialzip_t*) malloc(sizeof(partialzip_t));
    info->url = strdup(url);
    info->centralDirectoryRecvd = 0;
    info->centralDirectoryEndRecvd = 0;
    info->centralDirectoryDesc = NULL;
    info->progressCallback = NULL;

    info->hIPSW = curl_easy_init();

    curl_easy_setopt(info->hIPSW, CURLOPT_URL, info->url);
    curl_easy_setopt(info->hIPSW, CURLOPT_FOLLOWLOCATION, 1);
    curl_easy_setopt(info->hIPSW, CURLOPT_NOBODY, 1);
    curl_easy_setopt(info->hIPSW, CURLOPT_WRITEFUNCTION, dummyReceive);

    if(strncmp(info->url, "file://", 7) == 0)
    {
        char path[1024];
        strcpy(path, info->url + 7);
        char* filePath = (char*) curl_easy_unescape(info->hIPSW, path, 0,  NULL);
        FILE* f = fopen(filePath, "rb");
        if(!f)
        {
            curl_free(filePath);
            curl_easy_cleanup(info->hIPSW);
            free(info->url);
            free(info);

            return NULL;
        }

        fseek(f, 0, SEEK_END);
        info->length = ftell(f);
        fclose(f);

        curl_free(filePath);
    }
    else
    {
        curl_easy_perform(info->hIPSW);

        double dFileLength;
        curl_easy_getinfo(info->hIPSW, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &dFileLength);
        info->length = dFileLength;
    }

    char sRange[100];
    uint64_t start;

    if(info->length > (0xffff + sizeof(partialzip_end_of_cd_t)))
        start = info->length - 0xffff - sizeof(partialzip_end_of_cd_t);
    else
        start = 0;

    uint64_t end = info->length - 1;

    sprintf(sRange, "%" PRIu64 "-%" PRIu64, start, end);

    curl_easy_setopt(info->hIPSW, CURLOPT_WRITEFUNCTION, receiveCentralDirectoryEnd);
    curl_easy_setopt(info->hIPSW, CURLOPT_WRITEDATA, info);
    curl_easy_setopt(info->hIPSW, CURLOPT_RANGE, sRange);
    curl_easy_setopt(info->hIPSW, CURLOPT_HTTPGET, 1);
    curl_easy_perform(info->hIPSW);

    char* cur;
    for(cur = info->centralDirectoryEnd; cur < (info->centralDirectoryEnd + (end - start - 1)); cur++)
    {
        partialzip_end_of_cd_t* candidate = (partialzip_end_of_cd_t*) cur;
        uint32_t signature = candidate->signature;
        FLIPENDIANLE(signature);
        if(signature == 0x06054b50)
        {
            uint16_t lenComment = candidate->lenComment;
            FLIPENDIANLE(lenComment);
            if((cur + lenComment + sizeof(partialzip_end_of_cd_t)) == (info->centralDirectoryEnd + info->centralDirectoryEndRecvd))
            {
                FLIPENDIANLE(candidate->diskNo);
                FLIPENDIANLE(candidate->CDDiskNo);
                FLIPENDIANLE(candidate->CDDiskEntries);
                FLIPENDIANLE(candidate->CDEntries);
                FLIPENDIANLE(candidate->CDSize);
                FLIPENDIANLE(candidate->CDOffset);
                FLIPENDIANLE(candidate->lenComment);
                info->centralDirectoryDesc = candidate;
                break;
            }
        }

    }

    if(info->centralDirectoryDesc)
    {
        info->centralDirectory = (char*)malloc(info->centralDirectoryDesc->CDSize);
        start = info->centralDirectoryDesc->CDOffset;
        end = start + info->centralDirectoryDesc->CDSize - 1;
        sprintf(sRange, "%" PRIu64 "-%" PRIu64, start, end);
        curl_easy_setopt(info->hIPSW, CURLOPT_WRITEFUNCTION, receiveCentralDirectory);
        curl_easy_setopt(info->hIPSW, CURLOPT_WRITEDATA, info);
        curl_easy_setopt(info->hIPSW, CURLOPT_RANGE, sRange);
        curl_easy_setopt(info->hIPSW, CURLOPT_HTTPGET, 1);
        curl_easy_perform(info->hIPSW);

        flipFiles(info);

        return info;
    }
    else
    {
        curl_easy_cleanup(info->hIPSW);
        free(info->url);
        free(info);
        return NULL;
    }
}

partialzip_file_t* partialzip_find_file(partialzip_t* info, const char* fileName)
{
    char* cur = info->centralDirectory;
    unsigned int i;
    for(i = 0; i < info->centralDirectoryDesc->CDEntries; i++)
    {
        partialzip_file_t* candidate = (partialzip_file_t*) cur;
        const char* curFileName = cur + sizeof(partialzip_file_t);

        if(strlen(fileName) == candidate->lenFileName && strncmp(fileName, curFileName, candidate->lenFileName) == 0)
            return candidate;

        cur += sizeof(partialzip_file_t) + candidate->lenFileName + candidate->lenExtra + candidate->lenComment;
    }

    return NULL;
}

partialzip_file_t* partialzip_list_files(partialzip_t* info)
{
    char* cur = info->centralDirectory;
    unsigned int i;
    for(i = 0; i < info->centralDirectoryDesc->CDEntries; i++)
    {
        partialzip_file_t* candidate = (partialzip_file_t*) cur;
        const char* curFileName = cur + sizeof(partialzip_file_t);
        char* myFileName = (char*) malloc(candidate->lenFileName + 1);
        memcpy(myFileName, curFileName, candidate->lenFileName);
        myFileName[candidate->lenFileName] = '\0';

        printf("%s: method: %d, compressed size: %d, size: %d\n", myFileName, candidate->method,
                candidate->compressedSize, candidate->size);

        free(myFileName);

        cur += sizeof(partialzip_file_t) + candidate->lenFileName + candidate->lenExtra + candidate->lenComment;
    }

    return NULL;
}

unsigned char* partialzip_get_file(partialzip_t* info, partialzip_file_t* file)
{
    count = 0;
    partialzip_local_file_t localHeader;
    partialzip_local_file_t* pLocalHeader = &localHeader;

    uint64_t start = file->offset;
    uint64_t end = file->offset + sizeof(partialzip_local_file_t) - 1;
    char sRange[100];
    sprintf(sRange, "%" PRIu64 "-%" PRIu64, start, end);

    void* pFileHeader[] = {pLocalHeader, NULL, NULL, NULL};

    curl_easy_setopt(info->hIPSW, CURLOPT_URL, info->url);
    curl_easy_setopt(info->hIPSW, CURLOPT_FOLLOWLOCATION, 1);
    curl_easy_setopt(info->hIPSW, CURLOPT_WRITEFUNCTION, receiveData);
    curl_easy_setopt(info->hIPSW, CURLOPT_WRITEDATA, &pFileHeader);
    curl_easy_setopt(info->hIPSW, CURLOPT_RANGE, sRange);
    curl_easy_setopt(info->hIPSW, CURLOPT_HTTPGET, 1);
    curl_easy_perform(info->hIPSW);
    
    FLIPENDIANLE(localHeader.signature);
    FLIPENDIANLE(localHeader.versionExtract);
    // FLIPENDIANLE(localHeader.flags);
    FLIPENDIANLE(localHeader.method);
    FLIPENDIANLE(localHeader.modTime);
    FLIPENDIANLE(localHeader.modDate);
    // FLIPENDIANLE(localHeader.crc32);
    FLIPENDIANLE(localHeader.compressedSize);
    FLIPENDIANLE(localHeader.size);
    FLIPENDIANLE(localHeader.lenFileName);
    FLIPENDIANLE(localHeader.lenExtra);

    unsigned char* fileData = (unsigned char*) malloc(file->compressedSize);
    size_t progress = 0;
    void* pFileData[] = {fileData, info, file, &progress};

    start = file->offset + sizeof(partialzip_local_file_t) + localHeader.lenFileName + localHeader.lenExtra;
    end = start + file->compressedSize - 1;
    sprintf(sRange, "%" PRIu64 "-%" PRIu64, start, end);

    curl_easy_setopt(info->hIPSW, CURLOPT_WRITEFUNCTION, receiveData);
    curl_easy_setopt(info->hIPSW, CURLOPT_WRITEDATA, pFileData);
    curl_easy_setopt(info->hIPSW, CURLOPT_RANGE, sRange);
    curl_easy_setopt(info->hIPSW, CURLOPT_HTTPGET, 1);
    curl_easy_perform(info->hIPSW);

    if(file->method == 8)
    {
        unsigned char* uncData = (unsigned char*) malloc(file->size);
        z_stream strm;
        strm.zalloc = Z_NULL;
        strm.zfree = Z_NULL;
        strm.opaque = Z_NULL;
        strm.avail_in = 0;
        strm.next_in = NULL;

        inflateInit2(&strm, -MAX_WBITS);
        strm.avail_in = file->compressedSize;
        strm.next_in = fileData;
        strm.avail_out = file->size;
        strm.next_out = uncData;
        inflate(&strm, Z_FINISH);
        inflateEnd(&strm);
        free(fileData);
        fileData = uncData;
    }
    return fileData;
}

void partialzip_set_progress_callback(partialzip_t* info, partialzip_progress_callback_t progressCallback)
{
    info->progressCallback = progressCallback;
}

void partialzip_close(partialzip_t* info)
{
    curl_easy_cleanup(info->hIPSW);
    free(info->centralDirectory);
    free(info->url);
    free(info);

    curl_global_cleanup();
}


void partialzip_free_file(partialzip_file_t* file) {
    if(file) {
        free(file);
    }
}
