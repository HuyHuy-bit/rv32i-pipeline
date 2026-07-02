# RV32I Single-Cycle CPU

A single-cycle processor implementing the RV32I base integer instruction set, written in SystemVerilog and simulated with Verilator.

This is my **first ever hardware design project**. I started it knowing essentially nothing about computer architecture, and built it up block by block until it could execute real RISC-V programs. The notes below are as much a record of what I learned as a description of what the CPU does.

## What this CPU does

It's a working RV32I core. Each clock cycle, it fetches one instruction, decodes it, executes it, and writes the result back — all in a single cycle, with no pipelining. Concretely, it:

- Fetches a 32-bit instruction from instruction memory using the program counter.
- Decodes the opcode, `funct3`, and `funct7` fields to figure out what the instruction is and what control signals it needs.
- Reads up to two source registers, runs the ALU (or a comparison/jump unit), optionally touches data memory, and writes a result back to the destination register.
- Computes the next program counter — either the sequential `PC + 4`, a branch target, or a jump target — so control flow (branches, jumps, function calls) works.

The instruction set coverage is the full RV32I base, which means:

- **Arithmetic / logic:** `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLT`, `SLTU`, plus the immediate forms (`ADDI`, `ANDI`, etc.) and shifts (`SLL`, `SRL`, `SRA` and their immediate forms).
- **Branches:** all six — `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` — with correct signed vs. unsigned comparison.
- **Jumps:** `JAL` and `JALR`, including writing the return address, so functions can be called and returned from.
- **Upper immediates:** `LUI` and `AUIPC`.
- **Memory:** word, halfword, and byte loads/stores (`LW`, `LH`, `LHU`, `LB`, `LBU`, `SW`, `SH`, `SB`) with proper sign/zero extension and byte-lane write enables.

## Architecture

One module per file, wired together in `cpu.sv`:

| File | Role |
|------|------|
| `cpu.sv` | Top level. Instantiates every block and contains the datapath muxes (next-PC, write-back, ALU-A source). |
| `pc.sv` | Program counter register. Takes a resolved `next_pc` and latches it each cycle. |
| `instr_mem.sv` | Instruction memory (256 words). Holds the program as a hex array. |
| `reg_file.sv` | 32×32-bit register file. Two read ports (`rs1`/`rs2`), one write port (`rd`), with `x0` hardwired to zero. |
| `control.sv` | Main decoder. Maps opcode/`funct3`/`funct7` to all control signals and the ALU operation. |
| `imm_gen.sv` | Immediate generator. Produces I, S, B, U, and J-type immediates. |
| `alu.sv` | Arithmetic/logic unit. 11 operations including a pass-B op used by `LUI`. |
| `branch_unit.sv` | Branch comparator. Decodes `funct3` to evaluate all six branch conditions. |
| `data_mem.sv` | Data memory (1024 words) with byte-enable writes and subword load extension. |

### How the pieces connect

The next-PC logic is the heart of control flow. A mux driven by `pc_src` (from control) and the branch unit's verdict selects between `PC + 4`, the branch/jump target (`PC + imm`), and the `JALR` target (`(rs1 + imm) & ~1`). The write-back mux (`wb_src`) chooses what lands in the destination register: the ALU result, loaded memory data, or `PC + 4` (the return address for jumps). An ALU-A source mux lets `AUIPC` feed the PC into the ALU instead of `rs1`.

### Key encodings

ALU operations (`alu_op`):

```
0000 ADD    0001 SUB    0010 AND    0011 OR     0100 XOR
0101 SLT    0110 SLTU   0111 SLL    1000 SRL    1001 SRA
1010 PASS-B (used by LUI)
```

Register file port convention: `rs1_addr` / `rs2_addr` / `rd_addr` (5-bit), `rs1_data` / `rs2_data` / `rd_data` (32-bit).

## Building and running

Requires **Verilator** (simulation) and optionally **GTKWave** (waveform viewing).

```bash
make cpu     # build and run the simulation
make lint    # quick syntax/structure check, no build
make wave    # run, then open the waveform in GTKWave
make clean   # remove build artifacts and the trace
```

The program the CPU runs lives as a hex array in `instr_mem.sv`. The testbench (`cpu_tb.cpp`) drives the clock, prints registers `x1`–`x5` each cycle via debug taps, and self-checks the final register state. Every run also writes `cpu.vcd`, which you can open in GTKWave to watch the PC step, instructions flow, and branches redirect.

## What I learned

A running list of the things that actually made this click:

- **Signed vs. unsigned matters everywhere.** `BLT` vs. `BLTU` and `SLT` vs. `SLTU` only differ in how the comparison treats the top bit. In SystemVerilog a plain `logic [31:0]` compares unsigned by default, so the signed cases need explicit `$signed()` on *both* operands. Forgetting one side is a silent bug.

- **The muxes *are* the control flow.** Once I had the next-PC mux and the write-back mux, branches and jumps stopped being special — they were just a matter of selecting the right mux input. The datapath's branching structure lives in those select signals.

- **Immediate formats are scrambled on purpose.** The B-type and J-type immediates have their bits scattered across the instruction. It looks chaotic, but RISC-V keeps the sign bit at `instr[31]` for every format so the sign-extension hardware can be shared. Laying out each concatenation and checking it totals 32 bits was the way to get it right.

- **`LUI` is cleanest with a dedicated pass-through ALU op.** Rather than forcing `rs1 = x0` or adding a zero source, a "pass-B" operation that just outputs the immediate avoided extra muxes and special cases.

- **Two-level decode avoids a multi-driver error.** Splitting control into a main decode block and a separate ALU-op decode block (via an internal mode signal) was necessary so `alu_op` isn't assigned from two `always_comb` blocks at once.

- **Lint early, lint often.** Running Verilator's lint after every change caught missing semicolons, port-list comma slips, and width mismatches immediately, instead of letting them pile up.

- **Subword memory is all about lanes.** Byte and halfword stores write only part of a word using per-byte write enables, and loads pick the right lane from the address low bits before sign- or zero-extending. The store byte-enable mask and the data shift have to use the same offset, or the right byte lands in the wrong place.

## Roadmap (not yet done)

This is a complete single-cycle RV32I core, but there's plenty left to build:

- [ ] **Pipelining** — split into the classic 5 stages (IF/ID/EX/MEM/WB) with hazard detection, forwarding, and stalls. The big next step.
- [ ] **ISA extensions** — `M` (multiply/divide), `C` (compressed instructions).
- [ ] **FPGA synthesis** — run it on real hardware rather than simulation.

## Notes

- Misaligned accesses (e.g. `LW` to a non-word-aligned address) are not trapped; the core assumes aligned access, as is common for a simple learning design.
- This is a learning project, not a verified production core. It passes its own directed tests but has not been run against a formal RISC-V compliance suite.
