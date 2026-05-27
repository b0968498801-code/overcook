// Clock Divider: 100MHz -> 25MHz
// Basys3 onboard clock is 100MHz
// Divide by 4 to get 25MHz for VGA pixel clock

module clk_divider (
    input  logic clk_100m,
    input  logic rst,
    output logic clk_25m
);

    logic div2;

    always_ff @(posedge clk_100m or posedge rst) begin
        if (rst) begin
            div2    <= 0;
            clk_25m <= 0;
        end else begin
            div2 <= ~div2;
            if (div2)
                clk_25m <= ~clk_25m;
        end
    end

endmodule
