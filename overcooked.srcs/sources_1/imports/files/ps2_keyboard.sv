// PS/2 Keyboard Controller
// Decodes PS/2 serial protocol and outputs key press/release events
// Supports extended keys (E0 prefix) for arrow keys

module ps2_keyboard (
    input  logic        clk,
    input  logic        rst,
    input  logic        ps2_clk,
    input  logic        ps2_data,
    output logic [7:0]  scan_code,    // last received scan code
    output logic        key_press,    // pulse: key pressed
    output logic        key_release   // pulse: key released
);

    // Synchronize PS/2 clock to system clock (debounce)
    logic ps2_clk_sync0, ps2_clk_sync1, ps2_clk_sync2;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ps2_clk_sync0 <= 1;
            ps2_clk_sync1 <= 1;
            ps2_clk_sync2 <= 1;
        end else begin
            ps2_clk_sync0 <= ps2_clk;
            ps2_clk_sync1 <= ps2_clk_sync0;
            ps2_clk_sync2 <= ps2_clk_sync1;
        end
    end

    // Falling edge detect on PS/2 clock
    wire ps2_clk_fall = ps2_clk_sync2 & ~ps2_clk_sync1;

    // Receive 10 bits after start: 8 data bits LSB-first, parity, stop.
    logic [7:0] data_shift;
    logic [3:0] bit_cnt;
    logic       receiving;
    logic byte_ready;
    logic [7:0] rx_byte;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_shift <= 0;
            bit_cnt    <= 0;
            receiving  <= 0;
            byte_ready <= 0;
            rx_byte    <= 0;
        end else begin
            byte_ready <= 0;

            if (ps2_clk_fall) begin
                if (!receiving) begin
                    // Start bit must be 0.
                    if (!ps2_data) begin
                        receiving  <= 1;
                        bit_cnt    <= 0;
                        data_shift <= 0;
                    end
                end else begin
                    if (bit_cnt < 8)
                        data_shift[bit_cnt] <= ps2_data;

                    if (bit_cnt == 9) begin
                        // Stop bit should be 1. Parity is ignored for this game.
                        receiving <= 0;
                        if (ps2_data) begin
                            rx_byte    <= data_shift;
                            byte_ready <= 1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end
        end
    end

    // Handle break code (F0) and extended (E0)
    logic got_f0;   // next byte is release
    logic got_e0;   // extended key prefix

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            got_f0     <= 0;
            got_e0     <= 0;
            scan_code  <= 0;
            key_press  <= 0;
            key_release<= 0;
        end else begin
            key_press   <= 0;
            key_release <= 0;

            if (byte_ready) begin
                if (rx_byte == 8'hF0) begin
                    got_f0 <= 1;
                end else if (rx_byte == 8'hE0) begin
                    got_e0 <= 1;
                end else begin
                    scan_code <= rx_byte;
                    if (got_f0) begin
                        key_release <= 1;
                        got_f0      <= 0;
                        got_e0      <= 0;
                    end else begin
                        key_press   <= 1;
                        got_e0      <= 0;
                    end
                end
            end
        end
    end

endmodule
