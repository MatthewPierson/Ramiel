/*
 * instructions.h - function declarations for instructions.c
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
#include "decoders.h"

void write_opcode(uint8_t* buf, addr_t offset, uint32_t opcode);
int64_t signExtend(uint64_t x, int M);
uint32_t new_insn_adr(addr_t offset,uint8_t rd, int64_t addr);
uint32_t new_mov_register_insn(uint8_t rd, uint8_t rn, uint8_t rm, int64_t addr);
uint32_t new_movk_insn(uint8_t rd, uint16_t imm, uint8_t shift, uint8_t is64);
uint32_t new_ret_insn(int8_t rnn);
uint32_t new_mov_immediate_insn(uint8_t rd, uint16_t imm, uint8_t is64);
uint32_t replace_adr_addr(addr_t offset, uint32_t insn, int64_t addr);
uint32_t new_branch(int64_t where, int64_t addr);
uint32_t new_nop();