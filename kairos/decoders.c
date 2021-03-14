/*
 * decoders.c - functions for disassembling AARCH64 instructions into useful data
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

#define _GNU_SOURCE
#include "decoders.h"

// thank you tihmstar
uint64_t BIT_RANGE(uint64_t v, int begin, int end) { return ((v)>>(begin)) % (1 << ((end)-(begin)+1)); }
uint64_t BIT_AT(uint64_t v, int pos){ return (v >> pos) % 2; }
uint64_t SET_BITS(uint64_t v, int begin) { return ((v)<<(begin));}

insn_type_t get_type(uint32_t data) {
    enum insn_type type;
    if(BIT_RANGE(data, 24, 28) == 0b10000 && (data>>31))
        type = adrp;
    else if(BIT_RANGE(data, 24, 28) == 0b10000 && !(data>>31))
        type = adr;
    else if(BIT_RANGE(data, 24, 30) == 0b0010001)
        type = add;
    else if(BIT_RANGE(data, 24, 30) == 0b1010001)
        type = sub;
    else if((data>>26) == 0b100101)
        type = bl;
    else if(BIT_RANGE(data, 24, 30) == 0b0110100)
        type = cbz;
    else if(((0b11111 << 5) | data) == 0b11010110010111110000001111100000)
        type = ret;
    else if(BIT_RANGE(data, 24, 30) == 0b0110111)
        type = tbnz;
    else if(((0b11111 << 5) | data) == 0b11010110000111110000001111100000)
        type = br;
    else if((((data>>22) | 0b0100000000) == 0b1111100001 && ((data>>10) % 4)) || ((data>>22 | 0b0100000000) == 0b1111100101) || ((data>>23) == 0b00011000))
        type = ldr;
    else if(BIT_RANGE(data, 24, 30) == 0b0110101)
        type = cbnz;
    else if(BIT_RANGE(data, 23, 30) == 0b11100101)
        type = movk;
    else if(BIT_RANGE(data, 23, 30) == 0b01100100)
        type = orr;
    else if(BIT_RANGE(data, 23, 30) == 0b00100100)
        type = and_;
    else if(BIT_RANGE(data, 24, 30) == 0b0110110)
        type = tbz;
    else if((BIT_RANGE(data, 24, 29) == 0b001000) && (data >> 31) && BIT_AT(data, 22))
        type = ldxr;
    else if(BIT_RANGE(data, 21, 31) == 0b00111000010 || BIT_RANGE(data, 22, 31) == 0b0011100101  || (BIT_RANGE(data, 21, 31) == 0b00111000011 && BIT_RANGE(data, 10, 11) == 0b10))
        type = ldrb;
    else if((BIT_RANGE(data, 22, 29) == 0b11100100) && (data >> 31))
        type = str;
    else if((BIT_RANGE(data, 25, 30) == 0b010100) && !BIT_AT(data, 22))
        type = stp;
    else if((BIT_RANGE(data, 23, 30) == 0b10100101))
        type = movz;
    else if((BIT_RANGE(data, 24, 30) == 0b0101010) && (BIT_AT(data, 21) == 0))
        type = mov;
    else if((BIT_RANGE(data, 24, 31) == 0b01010100) && !BIT_AT(data, 4))
        type = bcond;
    else if((BIT_RANGE(data, 26, 31) == 0b000101))
        type = b;
    else if((BIT_RANGE(data, 12, 31) == 0b11010101000000110010) & (0b11111 % (1<<5)))
        type = nop;
    else if((BIT_RANGE(data, 21, 30) == 0b0011010100) && (BIT_RANGE(data, 10, 11) == 0b00))
        type = csel;
    else if((BIT_RANGE(data, 20, 31) == 0b110101010011))
        type = mrs;
    else if((BIT_RANGE(data, 21, 30) == 0b1101011001) || (BIT_RANGE(data, 24, 30) == 0b1101011) || (BIT_RANGE(data, 24, 30) == 0b1110001)) 
        type = subs;
    else if((BIT_RANGE(data, 21, 30) == 0b1111010010))
        type = ccmp;
    else
        type = unknown;
    return type; 
}

uint8_t get_rn(uint32_t offset){
    insn_type_t type = get_type(offset);
    switch (type) {
        case subs:
        case add:
        case sub:
        case ret:
        case br:
        case orr:
        case and_:
        case ldxr:
        case ldrb:
        case str:
        case ldr:
        case stp:
        case csel:
        case mov:
        case ccmp:
            return BIT_RANGE(offset, 5, 9);
        default:
            return -1;
            break;
    }
}

uint8_t get_rd(uint32_t insn) {
    insn_type_t type = get_type(insn);
    switch (type) {
        case unknown:
            return -1;
            break;
        case subs:
        case adrp:
        case adr:
        case add:
        case sub:
        case movk:
        case orr:
        case and_:
        case movz:
        case mov:
        case csel:
            return (insn % (1<<5));
        default:
            return -1;
            break;
    }
}

uint8_t get_rm(uint32_t insn) {
    insn_type_t type = get_type(insn);
    switch(type) {
        case ccmp:
        case csel:
        case mov:
        case subs:
            return BIT_RANGE(insn, 16, 20);
        default:
            return -1;
            break;
    }
}

enum supertype get_supertype(uint32_t insn) {
    insn_type_t type = get_type(insn);
    switch(type) {
        case bl:
        case cbz:
        case cbnz:
        case tbnz:
        case bcond:
        case b:
            return supertype_branch_immediate;
        case ldr:
        case ldrb:
        case ldxr:
        case str:
        case stp:
            return supertype_memory;
        default:
            return supertype_general;
    }
}
// end tihmstar decoding functions

uint32_t get_insn(uint8_t* buf, addr_t offset) {
    uint32_t data = 0;
    data = *(uint32_t*)(buf+offset);
    return data;
}

uint64_t get_ptr_loc(uint8_t* buf, addr_t offset) {
    return *(uint64_t*)(buf+offset);
}

int64_t get_addr_for_adr(addr_t offset,uint32_t insn) {
    uint64_t pc = offset / 4; // yup. that easy
    //printf("offset: %llx\n",offset);
    //uint64_t immlo = BIT_RANGE(insn,29,30);
    //uint64_t immhi = BIT_RANGE(insn,5,23);
    //uint64_t immf = (BIT_RANGE(insn,5,23) << 2) | BIT_RANGE(insn,29,30); // immhi:immlo
    int64_t imm = signExtend((BIT_RANGE(insn,5,23) << 2) | BIT_RANGE(insn,29,30),21);
    //printf("PC-rel for : %llx\n",imm);
    return imm + pc;
}

int64_t get_addr_for_bl(addr_t offset, uint32_t insn) {
    uint64_t pc = offset/4;
    uint64_t uimm = 0;
    uimm = BIT_RANGE(insn,0,25) << 2; // imm:'00'
    int64_t imm = signExtend(uimm,64);
    return imm + pc;
}

int64_t get_addr_for_cbz(addr_t offset, uint32_t insn) {
    uint64_t pc = offset/4;
    uint64_t uimm = 0;
    uimm = BIT_RANGE(insn,5,23) << 2; // imm:'00'
    int64_t imm = signExtend(uimm,25);
    return imm + pc;
}

addr_t get_prev_nth_insn(uint8_t* buf, addr_t offset, int n, insn_type_t type) {
    for(int i = 0; i < n; i++) {
        offset -= 4;
        while(get_type(get_insn(buf,offset)) != type)
            offset -= 4;
    }
    return offset;
}

addr_t get_next_nth_insn(uint8_t* buf, addr_t offset, int n, insn_type_t type) {
    for(int i = 0; i < n; i++) {
        offset += 4;
        while(get_type(get_insn(buf,offset)) != type)
            offset += 4;
    }
    return offset;
}

char* uint64_to_hex(uint64_t num) {
    char* res = NULL;
    //uint8_t scratch = 0;
    asprintf(&res,"%s\\x%02llx","", (num >> 0) & 0xFF);
    asprintf(&res,"%s\\x%02llx",res, (num >> 8) & 0xFF);
    asprintf(&res,"%s\\x%02llx",res, (num >> 16) & 0xFF);
    asprintf(&res,"%s\\x%02llx",res, (num >> 24) & 0xFF);
    asprintf(&res,"%s\\x%02llx",res, (num >> 32) & 0xFF);
    asprintf(&res,"%s\\x%02llx",res, (num >> 40) & 0xFF);
    asprintf(&res,"%s\\x%02llx",res, (num >> 48) & 0xFF);
    asprintf(&res,"%s\\x%02llx",res, (num >> 56) & 0xFF);
    return res;
}
