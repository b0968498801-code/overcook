// VGA Controller for 640x480 @ 60Hz
// Basys3: 100MHz input clock, advances pixels with a 25MHz clock enable
// Horizontal: 640 visible + 16 front porch + 96 sync + 48 back porch = 800 total
// Vertical:   480 visible + 10 front porch +  2 sync + 33 back porch = 525 total

module vga_controller (
    input  logic        clk,        // 100MHz system clock
    input  logic        rst,
    output logic [9:0]  pixel_x,    // 0~639 visible
    output logic [9:0]  pixel_y,    // 0~479 visible
    output logic        h_sync,
    output logic        v_sync,
    output logic        video_on    // 1 = visible area
);

    // Horizontal timing
    localparam H_VISIBLE    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = 800;

    // Vertical timing
    localparam V_VISIBLE    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = 525;

    logic [9:0] h_count, v_count;
    logic [1:0] pix_div;
    logic       pix_tick;

    assign pix_tick = (pix_div == 2'd0);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pix_div <= 0;
        else
            pix_div <= pix_div + 1;
    end

    // Horizontal counter
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            h_count <= 0;
        else if (pix_tick) begin
            if (h_count == H_TOTAL - 1)
                h_count <= 0;
            else
                h_count <= h_count + 1;
        end
    end

    // Vertical counter
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            v_count <= 0;
        else if (pix_tick && h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end
    end

    // Sync signals (active low)
    assign h_sync  = ~((h_count >= H_VISIBLE + H_FRONT) && 
                       (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
    assign v_sync  = ~((v_count >= V_VISIBLE + V_FRONT) && 
                       (v_count <  V_VISIBLE + V_FRONT + V_SYNC));

    // Visible area
    assign video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    // Pixel coordinates
    assign pixel_x = (video_on) ? h_count : 10'd0;
    assign pixel_y = (video_on) ? v_count : 10'd0;

endmodule
