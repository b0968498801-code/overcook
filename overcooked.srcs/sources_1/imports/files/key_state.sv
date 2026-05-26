// Key State Tracker
// Maintains which keys are currently held down
// Scan codes for Basys3 PS/2:
//   W=1D  A=1C  S=1B  D=23  F=2B
//   UP=75 DOWN=72 LEFT=6B RIGHT=74  (these come with E0 prefix but we ignore E0 here)
//   ENTER=5A

module key_state (
    input  logic        clk,
    input  logic        rst,
    input  logic [7:0]  scan_code,
    input  logic        key_press,
    input  logic        key_release,

    // P1: WASD + F
    output logic        p1_up,
    output logic        p1_down,
    output logic        p1_left,
    output logic        p1_right,
    output logic        p1_interact,

    // P2: Arrow keys + Enter
    output logic        p2_up,
    output logic        p2_down,
    output logic        p2_left,
    output logic        p2_right,
    output logic        p2_interact
);

    // PS/2 scan codes (Set 2)
    localparam KEY_W     = 8'h1D;
    localparam KEY_A     = 8'h1C;
    localparam KEY_S     = 8'h1B;
    localparam KEY_D     = 8'h23;
    localparam KEY_F     = 8'h2B;
    localparam KEY_UP    = 8'h75;
    localparam KEY_DOWN  = 8'h72;
    localparam KEY_LEFT  = 8'h6B;
    localparam KEY_RIGHT = 8'h74;
    localparam KEY_ENTER = 8'h5A;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            p1_up       <= 0; p1_down    <= 0;
            p1_left     <= 0; p1_right   <= 0;
            p1_interact <= 0;
            p2_up       <= 0; p2_down    <= 0;
            p2_left     <= 0; p2_right   <= 0;
            p2_interact <= 0;
        end else if (key_press) begin
            case (scan_code)
                KEY_W:     p1_up       <= 1;
                KEY_S:     p1_down     <= 1;
                KEY_A:     p1_left     <= 1;
                KEY_D:     p1_right    <= 1;
                KEY_F:     p1_interact <= 1;
                KEY_UP:    p2_up       <= 1;
                KEY_DOWN:  p2_down     <= 1;
                KEY_LEFT:  p2_left     <= 1;
                KEY_RIGHT: p2_right    <= 1;
                KEY_ENTER: p2_interact <= 1;
                default: ;
            endcase
        end else if (key_release) begin
            case (scan_code)
                KEY_W:     p1_up       <= 0;
                KEY_S:     p1_down     <= 0;
                KEY_A:     p1_left     <= 0;
                KEY_D:     p1_right    <= 0;
                KEY_F:     p1_interact <= 0;
                KEY_UP:    p2_up       <= 0;
                KEY_DOWN:  p2_down     <= 0;
                KEY_LEFT:  p2_left     <= 0;
                KEY_RIGHT: p2_right    <= 0;
                KEY_ENTER: p2_interact <= 0;
                default: ;
            endcase
        end
    end

endmodule
