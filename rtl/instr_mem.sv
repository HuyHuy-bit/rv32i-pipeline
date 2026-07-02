module instr_mem (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    logic [31:0] mem [0:255];
    string mem_file;

    initial begin
        if (!$value$plusargs("MEMFILE=%s", mem_file))
            mem_file = "tests/t01_rtype.hex";
        $readmemh(mem_file, mem);
    end

    assign instr = mem[addr[9:2]];
endmodule