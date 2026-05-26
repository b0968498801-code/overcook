`timescale 1ns / 1ps

module image_rom (
    input  logic        clk,
    input  logic [16:0] addr,
    output logic [11:0] data
);

    (* rom_style = "block" *) logic [11:0] mem [0:76799];

    initial begin
        $readmemb("image_rom.mem", mem);
    end

    always_ff @(posedge clk) begin
        data <= mem[addr];
    end

endmodule
