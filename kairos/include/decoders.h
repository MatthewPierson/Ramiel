/*
 * decoders.h - function declarations and defines for decoders.c
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

// tihmstar stuff
typedef enum insn_type{unknown, adr, adrp, bl, cbz, ret, tbnz, add, sub, br, ldr, cbnz, movk, orr, tbz, ldxr, ldrb, str, stp, movz, bcond, b, nop, and_, csel, mov, mrs, subs, cmp = subs, ccmp} insn_type_t;
enum supertype { supertype_general, supertype_branch_immediate, supertype_memory };
uint64_t BIT_RANGE(uint64_t v, int begin, int end);
uint64_t BIT_AT(uint64_t v, int pos);
uint64_t SET_BITS(uint64_t v, int begin);
// Credit goes to them for the previous declarations

insn_type_t get_type(uint32_t data);
uint8_t get_rn(uint32_t offset);
uint8_t get_rd(uint32_t insn);
uint8_t get_rm(uint32_t insn);
enum supertype get_supertype(uint32_t insn);
uint32_t get_insn(uint8_t* buf, addr_t offset);
uint64_t get_ptr_loc(uint8_t* buf, addr_t offset);
int64_t get_addr_for_adr(addr_t offset,uint32_t insn);
int64_t get_addr_for_bl(addr_t offset, uint32_t insn);
int64_t get_addr_for_cbz(addr_t offset, uint32_t insn);
addr_t get_prev_nth_insn(uint8_t* buf, addr_t offset, int n, insn_type_t type);
addr_t get_next_nth_insn(uint8_t* buf, addr_t offset, int n, insn_type_t type);
char* uint64_to_hex(uint64_t num);