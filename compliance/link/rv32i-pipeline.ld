/* rv32i-pipeline.ld — linker script for the Harvard-split CPU.
 *
 * The CPU has two INDEPENDENT physical memories:
 *   - instr_mem (2MB), fed by the PC (fetch address)
 *   - data_mem  (64KB), fed by the ALU result (load/store address)
 * Each memory's address decode only looks at its low bits - bits above
 * that are ignored. RAM is placed at 0x00300000 (past the end of the
 * 2MB ROM region) so the two regions never overlap in the linker's view,
 * while RAM's low bits still alias correctly back into data_mem's own
 * word 0 upward.
 */

MEMORY
{
    ROM (rxa) : ORIGIN = 0x00000000, LENGTH = 0x200000  /* 2MB -> instr_mem */
    RAM (wxa) : ORIGIN = 0x00300000, LENGTH = 0x10000    /* 64KB -> data_mem */
}

ENTRY(rvtest_entry_point)

SECTIONS
{
    .text.init : { *(.text.init) } > ROM

    .text : {
        *(.text)
        *(.text.*)
    } > ROM

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > ROM

    .data : {
        _data = .;
        *(.data)
        *(.data.*)
        _edata = .;
    } > RAM

    .bss : {
        _bss = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _ebss = .;
    } > RAM

    .tohost : { *(.tohost) } > RAM

    _end = .;

    . = ORIGIN(RAM) + LENGTH(RAM) - 4;
    _stack_top = .;
}
