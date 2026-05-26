// Seven Segment Display Controller
// Basys3 has 4 digits, common anode
// Displays countdown seconds across all four digits.

module seven_seg (
    input  logic        clk,        // 100MHz
    input  logic        rst,
    input  logic [7:0]  seconds,    // 0~180
    input  logic [7:0]  score_disp, // 0~99 for display (can show score mod 100)
    output logic [3:0]  an,         // anode (active low), an[3]=leftmost
    output logic [6:0]  seg         // segments (active low): gfedcba
);

    // Multiplexing counter (~1kHz refresh)
    logic [16:0] refresh_cnt;
    logic [1:0]  digit_sel;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) refresh_cnt <= 0;
        else     refresh_cnt <= refresh_cnt + 1;
    end
    assign digit_sel = refresh_cnt[16:15];

    // Digit values
    logic [3:0] digit3, digit2, digit1, digit0;
    assign digit3 = seconds / 1000;
    assign digit2 = (seconds / 100) % 10;
    assign digit1 = (seconds / 10) % 10;
    assign digit0 = seconds % 10;

    // Anode select
    always_comb begin
        case (digit_sel)
            2'd0: an = 4'b1110; // digit0 (rightmost)
            2'd1: an = 4'b1101;
            2'd2: an = 4'b1011;
            2'd3: an = 4'b0111; // digit3 (leftmost)
        endcase
    end

    // Current digit value
    logic [3:0] curr_digit;
    always_comb begin
        case (digit_sel)
            2'd0: curr_digit = digit0;
            2'd1: curr_digit = digit1;
            2'd2: curr_digit = digit2;
            2'd3: curr_digit = digit3;
        endcase
    end

    // 7-segment decoder (active low, common anode)
    // seg = {g, f, e, d, c, b, a}
    always_comb begin
        case (curr_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // blank
        endcase
    end

endmodule
