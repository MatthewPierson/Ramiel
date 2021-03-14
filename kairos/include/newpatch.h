/*
 * newpatch.h - function declarations and defines for newpatch.c
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

#pragma once
#include "patchfinder64.h"
#include "instructions.h"

#define ENTERING_RECOVERY_CONSOLE "Entering recovery mode, starting command prompt"
#define KERNELCACHE_PREP_STRING "__PAGEZERO"
#define IMAGE4_MAGIC "IM4P"
#define KERNEL_LOAD_STRING "__PAGEZERO"
#define DEFAULT_BOOTARGS_STRING "rd=md0 nand-enable-reformat=1 -progress"
#define OTHER_DEFAULT_BOOTARGS_STRING "rd=md0 -progress -restore"
#define CERT_STRING "Reliance on this"
#define DART_CTRR_STRING "void dart_ctrr_reconfig" // From what I can tell the "Reliance on this..." string is gone as of iOS 13.x :(

struct iboot64_img { // from iBoot32Patcher
	void* buf;
	size_t len;
	uint32_t VERS;
	uint64_t base;
} __attribute__((packed));

#define LOG(fmt, ...) printf("[+] " fmt, ##__VA_ARGS__);
#define WARN(fmt, ...) printf("[!] " fmt, ##__VA_ARGS__);

#define GET_IBOOT64_ADDR(iboot_in, x) (x - (uintptr_t) iboot_in->buf) + iboot_in->base
#define GET_IBOOT_FILE_OFFSET(iboot_in, x) (x - (uintptr_t) iboot_in->buf)

bool has_magic(uint8_t* buf);
int patch_boot_args64(struct iboot64_img* iboot_in, char* bootargs);
uint64_t get_iboot64_base_address(struct iboot64_img* iboot_in);
uint32_t get_iboot64_main_version(struct iboot64_img* iboot_in);
uint64_t iboot64_ref(struct iboot64_img* iboot_in, void* pat);
int enable_kernel_debug(struct iboot64_img* iboot_in);
int rsa_sigcheck_patch(struct iboot64_img* iboot_in);
bool has_kernel_load_k(struct iboot64_img* iboot_in);
bool has_recovery_console_k(struct iboot64_img* iboot_in);
int do_command_handler_patch(struct iboot64_img* iboot_in, char* command, uintptr_t ptr);
int unlock_nvram(struct iboot64_img* iboot_in);