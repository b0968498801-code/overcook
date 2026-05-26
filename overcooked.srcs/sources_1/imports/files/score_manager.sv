// Score Manager
// +10 on successful serve, -5/-10/-15 on order timeout

module score_manager (
    input  logic        clk,
    input  logic        rst,
    input  logic        game_active,
    input  logic        order_matched,  // +score
    input  logic        order_expired,  // -score
    input  logic [1:0]  difficulty,     // 00=easy 01=normal 10=hard
    output logic [7:0]  score           // 0~255
);

    localparam SCORE_SERVE   = 8'd10;
    logic [7:0] penalty;

    always_comb begin
        case (difficulty)
            2'd0:    penalty = 8'd5;
            2'd1:    penalty = 8'd10;
            2'd2:    penalty = 8'd15;
            default: penalty = 8'd10;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || !game_active)
            score <= 8'd0;
        else begin
            if (order_matched)
                score <= score + SCORE_SERVE;
            else if (order_expired) begin
                if (score >= penalty)
                    score <= score - penalty;
                else
                    score <= 8'd0;
            end
        end
    end

endmodule
