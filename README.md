# RV32I 5-Stage Pipelined CPU

A 5-stage pipelined processor implementing the RV32I base integer instruction set, written in SystemVerilog and simulated with Verilator. This is the direct successor to [`rv32i-datapath-singlecycle`](https://github.com/HuyHuy-bit/rv32i-datapath-singlecycle) — same instruction set, same test programs, restructured into IF → ID → EX → MEM → WB stages with forwarding and hazard handling.

## What this CPU does

Every cycle, up to five different instructions are in flight at once, each at a different stage of execution:

- **IF** — fetch the instruction at the current PC.
- **ID** — decode opcode/`funct3`/`funct7`, read the register file, generate the immediate.
- **EX** — run the ALU (or the branch comparator), resolve branch/jump targets, forward operands from later stages if needed.
- **MEM** — access data memory for loads/stores.
- **WB** — write the result back to the register file.

Instruction set coverage is unchanged from Week 2 — the full RV32I base: all R/I-type ALU ops, all six branches, `JAL`/`JALR`, `LUI`/`AUIPC`, and all load/store widths with correct sign/zero extension.

## What changed from the single-cycle version

Almost nothing at the module level. `alu.sv`, `control.sv`, `imm_gen.sv`, `branch_unit.sv`, `data_mem.sv`, `pc.sv`, and `instr_mem.sv` are untouched — the single-cycle datapath was modular enough that pipelining meant *adding* structure around those blocks, not rewriting them. What's new:

| File | Role |
|------|------|
| `if_id_reg.sv` | IF/ID pipeline register. Supports `flush` (control hazard) and `stall` (load-use hazard). |
| `id_ex_reg.sv` | ID/EX pipeline register. Carries both datapath values and every control signal forward; `flush` zeroes all of it to insert a bubble. |
| `ex_mem_reg.sv` | EX/MEM pipeline register. |
| `mem_wb_reg.sv` | MEM/WB pipeline register. |
| `forwarding_unit.sv` | Resolves RAW hazards by routing EX/MEM or MEM/WB results back into the EX stage instead of the (possibly stale) ID/EX-registered operand. |
| `hazard_detect.sv` | Detects load-use — the one RAW case forwarding can't reach — and asserts a 1-cycle stall. |
| `cpu.sv` | Rewritten. Strings the five stages together through the pipeline registers above, plus the branch/jump flush and load-use stall control logic. |
| `reg_file.sv` | One addition: a read-during-write bypass, so a WB-stage write and an ID-stage read of the same register on the same cycle resolve correctly (see below). |

### The three hazard problems, and how each is solved

**1. Control hazards (branches/jumps).** Branches and jumps resolve in EX, but by then IF and ID have already fetched and decoded the two instructions sequentially after it — the wrong path, if the branch is taken. This design uses the simplest possible fix: assume not-taken, and if EX resolves a branch as taken (or hits a `JAL`/`JALR`, which is unconditional), flush IF/ID and ID/EX and redirect the PC. That's a 2-cycle penalty on every taken branch/jump, with no prediction. A real branch predictor is future work (see Roadmap).

**2. Data hazards, general case (RAW).** An instruction whose source register was written by an instruction 1–2 slots ahead of it in the pipeline would otherwise read a stale value out of the register file. `forwarding_unit.sv` compares the EX stage's `rs1`/`rs2` against the destination registers currently sitting in EX/MEM and MEM/WB, and routes the correct in-flight value into the ALU and branch comparator instead. EX/MEM takes priority over MEM/WB, since it's the more recent producer.

**3. Data hazards, load-use.** If the producer is a load and the consumer is the *very next* instruction, forwarding can't help — the loaded value isn't back from memory yet when EX needs it. `hazard_detect.sv` catches this specific pattern and stalls the pipeline for exactly one cycle (holding the PC and IF/ID, bubbling ID/EX) so the consumer re-reads its operand one cycle later, by which point ordinary EX/MEM→EX forwarding picks it up normally.

**A fourth, narrower case** surfaced during testing: when a producer and consumer are exactly 3 instructions apart, the producer's WB-stage write and the consumer's ID-stage read of the same register land on the *same* clock edge. Neither the forwarding unit nor the hazard-detect unit reaches this (it's a WB→ID collision, not WB→EX). The fix is a small bypass inside `reg_file.sv` itself: if the register being written this cycle matches the register being read this cycle, output the incoming write data instead of the (about-to-be-stale) array contents.

## Building and running

Requires **Verilator** (simulation) and optionally **GTKWave** (waveform viewing) — same as Week 2.

```bash
make cpu     # build and run the simulation
make lint    # quick syntax/structure check, no build
make wave    # run, then open the waveform in GTKWave
make clean   # remove build artifacts and traces
```

## Test suite

All of Week 2's directed tests carry over unchanged in *expected values* — a pipelined CPU should produce identical architectural results to the single-cycle version, just spread across more cycles. The `cycles=` budget in each `.ref` file was bumped by roughly 4–6 cycles versus Week 2 to account for pipeline fill/drain latency (the last instruction's result doesn't land until 4 cycles after it's fetched, instead of 1).

| Test | Covers |
|------|--------|
| `t01_rtype` | All ten R-type ALU ops |
| `t02_itype` | Immediate ALU ops + immediate shifts |
| `t03_memory` | All load/store widths, sign/zero extension |
| `t04_branch` | All six branch conditions |
| `t05_jump` | `JAL` / `JALR` |
| `t06_lui_auipc` | Upper-immediate instructions |
| `t07_load_use` | **New.** Three load-use hazard patterns: back-to-back, both-operands, rs2-only. Added specifically because none of the Week 2 tests happen to exercise this pattern — verified it actually fails without `hazard_detect.sv` in place before trusting it as a pass. |

**7/7 passing.**

## What I learned

- **A clean single-cycle datapath pays off twice.** Splitting into modules for the single-cycle build meant pipelining didn't touch the ALU, control decode, or memory logic at all — only the top-level wiring and a handful of new register/hazard modules.
- **Branches don't just need flushing logic — they need *something* using stale data first, to notice.** The 2-cycle flush penalty is only correct because it's paired with forwarding *inside* EX; without forwarding, a branch's own comparison could be wrong before the flush even matters.
- **Forwarding and load-use hazards are two different problems, not one.** It's tempting to think "forwarding fixes RAW hazards" as a single fact — it fixes the ones where the value already exists somewhere in the pipeline. Load-use fails specifically because, for one cycle, the value doesn't exist anywhere yet.
- **The narrowest hazard is the easiest to miss.** The 3-instruction-gap WB/ID collision didn't show up until running the actual Week 2 test programs through the new pipeline — it doesn't fit the "adjacent instructions" mental model that motivates forwarding and stalling, so it's easy to assume forwarding covers it when it structurally can't.
- **A pipeline needs new tests, not just old ones passing.** 6/6 on the original suite would have been a false sense of completeness — none of those programs happened to contain a load-use pattern, so a real bug (verified by deliberately breaking it) would have shipped silently.

## Roadmap (not yet done)

- [ ] **Branch prediction** — replace "always flush on taken" with a simple predictor (static not-taken, or a BTB) to cut the control-hazard penalty.
- [ ] **Structural hazards** — currently instruction and data memory are separate arrays, so there's no structural hazard to handle yet; would apply if merged into a unified memory.
- [ ] **ISA extensions** — `M` (multiply/divide), `C` (compressed instructions).
- [ ] **FPGA synthesis** — run it on real hardware rather than simulation.

## Notes

- This is a learning project, not a verified production core. It passes its own directed tests but has not been run against a formal RISC-V compliance suite.