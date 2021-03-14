/*
 * main.c - main file for using kairos, used to patch unpacked IM4P iOS bootloader images
 *
 * Copyright 2020 dayt0n
 *
 * This file is part of kairos.
 *
 * kairos is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * kairos is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with kairos.  If not, see <https://www.gnu.org/licenses/>.
*/

#include "kairos.h"
#include "newpatch.h"

int patchIBXX(char* in, char* out, char* bootArgsInput) {
	
	char* inFile = in;
	char* outFile = out;
	char* bootArgs = NULL;
	char* command_str = NULL;
	uint64_t command_ptr = 0;
	struct iboot64_img iboot_in;
	int ret = 0;
	memset(&iboot_in, 0, sizeof(iboot_in));
	bool doNvramUnlock = true;

	bootArgs = bootArgsInput;
    
	// read in image
	FILE* fp = fopen(inFile,"rb");
	if(!fp) {
		printf("Error opening %s for reading\n",inFile);
		return -1;
	}
	fseek(fp,0,SEEK_END);
	iboot_in.len = ftell(fp);
	fseek(fp,0,SEEK_SET);
	iboot_in.buf = (uint8_t*)malloc(iboot_in.len);
	if(!iboot_in.buf) {
		printf("Error allocating 0x%lx bytes\n",iboot_in.len);
		return -1;
	}
	fread(iboot_in.buf,1,iboot_in.len,fp);
	fflush(fp);
	fclose(fp);
	// patch
	LOG("Patching %s\n",inFile);
	if(has_magic(iboot_in.buf)) { // make sure we aren't dealing with a packed IMG4 container
		WARN("%s does not appear to be stripped\n",inFile);
		return -1;
	}
	LOG("Base address: 0x%llx\n",get_iboot64_base_address(&iboot_in));
	if(has_kernel_load_k(&iboot_in)) {
		LOG("Does have kernel load\n");
		if(bootArgs) {
			LOG("Patching boot-args...\n");
			patch_boot_args64(&iboot_in,bootArgs);
		}
		LOG("Enabling kernel debug...\n");
		ret = enable_kernel_debug(&iboot_in);
		if(ret < 0) // won't fail because it is not fatal, but it would really be nice if we had k-debug
			WARN("Could not enable kernel debug\n");
	}
	if(has_recovery_console_k(&iboot_in)) {
		if(command_str && (command_ptr != 0)) { // need to reassign command handler
			LOG("Changing command handler %s to 0x%llx...\n",command_str,command_ptr);
			ret = do_command_handler_patch(&iboot_in,command_str,command_ptr);
			if(ret < 0) // do not exit, just continue without cmdhandler patch
				WARN("Failed to patch command handler for %s\n",command_str);
		}
		if(doNvramUnlock) {
			LOG("Unlocking nvram...\n");
			ret = unlock_nvram(&iboot_in);
			if(ret < 0)
				WARN("Failed to unlock nvram\n");
		}
	}
	LOG("Patching out RSA signature check...\n");
	ret = rsa_sigcheck_patch(&iboot_in);
	if(ret < 0)
		WARN("Error patching out RSA signature check\n");
	// now write file
	fp = fopen(outFile,"wb+");
	if(!fp) {
		printf("Error opening %s for writing\n",outFile);
		free(iboot_in.buf);
		return -1;
	}
	fwrite(iboot_in.buf,1,iboot_in.len,fp);
	fflush(fp);
	fclose(fp);
	free(iboot_in.buf);
	LOG("Wrote patched image to %s\n",outFile);
	return 0;
}
