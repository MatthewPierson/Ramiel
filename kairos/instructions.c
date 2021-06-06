/*
 * instructions.c - functions for modifying or assembling new AARCH64 instructions 
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

#include "instructions.h"

void write_opcode(uint8_t* buf, addr_t offset, uint32_t opcode) {
    *(uint32_t*)(buf+offset) = opcode;
}

int64_t signExtend(uint64_t x, int M) { // from tihmstar
    // count bits
    uint64_t extended = (x & 1 << (M-1))>>(M-1);
    for (int i=M; i<64; i++)
        x |= extended << i;
    return x;
}

uint32_t new_insn_adr(addr_t offset,uint8_t rd, int64_t addr) {
    uint32_t opcode = 0;
    opcode |= SET_BITS(0x10,24); // set adr 
    opcode |= (rd % (1<<5)); // set rd
    // we have a pc rel address
    // do difference validations
    int64_t diff = addr - offset; // addr - offset to get pc rel
    if(diff > 0) {
        if(diff > (1LL<<20)) // diff is too long, won't be able to fit
            return -1;
        else if(-diff > (1LL<<20)) // again, diff is too long but it is a signed int
            return -1;
    }
    opcode |= SET_BITS(BIT_RANGE(diff,0,1),29); // set pos 30-29 to immlo
    opcode |= SET_BITS(BIT_RANGE(diff,2,20),5); // set pos 23-5  to immhi
    return opcode;
}

uint32_t new_mov_register_insn(uint8_t rd, uint8_t rn, uint8_t rm, int64_t addr) {
    uint32_t opcode = 0;
    opcode |= SET_BITS(0x1,31); // set up sf
    opcode |= SET_BITS(0x150,21); // set up opcode, shift, and N
    opcode |= (rd % (1<<5)); // set up rd 
    opcode |= SET_BITS(rm & 0x1F, 16); // set up rm
    opcode |= SET_BITS(rn & 0x1F, 5); // set up rn
    opcode |= SET_BITS(addr & 0x3F, 10); // set addr immediate
    return opcode;
}

uint32_t new_movk_insn(uint8_t rd, uint16_t imm, uint8_t shift, uint8_t is64) {
    uint32_t opcode = 0;
    if (is64 != 0)
        opcode |= SET_BITS(0x1,31);
    else
        opcode |= SET_BITS(0x0,31);
    opcode |= SET_BITS(0xE5,23);
    if (shift != 0) // set hw if needed
        opcode |= SET_BITS(shift>>4,21);
    opcode |= SET_BITS(imm,5);
    opcode |= (rd % (1<<5));
    return opcode;
}

uint32_t new_ret_insn(int8_t rnn) { // ret x[rn], default rn value is 13. just set to -1 for default
    uint32_t opcode = 0;
    if(rnn >= 0) { 
        if (rnn > (rnn << 3))
            printf("[!] Shortening rn for ret intruction\n");
        rnn = rnn << 3;
    } else
        rnn = 30;
    uint8_t rn = (uint8_t)rnn;
    opcode |= SET_BITS(0xD65F,16);
    opcode |= SET_BITS(rn % (1<<5),5);
    // after this, everything is 0 so nothing left to do
    return opcode;
}

uint32_t new_mov_immediate_insn(uint8_t rd, uint16_t imm, uint8_t is64) { // movz x<rd>, #imm
    uint32_t opcode = 0;
    if (is64 == 1) // if is64, do a x<rd>, if not, do w<rd>
        opcode |= SET_BITS(0x1,31); // set sf
    else
        opcode |= SET_BITS(0x0,31);
    opcode |= SET_BITS(0x294,21); // set opcode, hw
    opcode |= SET_BITS(imm,5); // set imm
    opcode |= (rd % (1<<5)); // set rd
    return opcode;
}

uint32_t replace_adr_addr(addr_t offset, uint32_t insn, int64_t addr) {
    uint32_t opcode = 0;
    uint8_t rd = get_rd(insn);
    opcode = new_insn_adr(offset,rd,addr);
    return opcode;
}

uint32_t new_branch(int64_t where, int64_t addr) {
    int64_t res = 0;
    uint32_t opcode = 0;
    opcode |= SET_BITS(0x5,26);
    res = (addr - where) / 4;
    opcode |= (res % (1<<25));
    return opcode;
}

uint32_t new_nop() {
    return 0xD503201F;
}