// Order Manager
// Generates random orders (burger/soup noodle/rice bowl)
// Tracks timeout and handles serve matching
// Max 3 simultaneous orders (Hard mode)

module order_manager (
    input  logic        clk,
    input  logic        rst,
    input  logic        game_active,
    input  logic        tick_1hz,

    // Difficulty
    input  logic [1:0]  difficulty,     // 00=easy 01=normal 10=hard
    input  logic [4:0]  order_timeout,  // 28/25/23 seconds
    input  logic [1:0]  max_orders,     // 1/2/3

    // Serve event
    input  logic [1:0]  served_dish,    // 1=burger 2=soup noodle 3=rice bowl
    input  logic [1:0]  served_slot,    // 0~2 order port, 3=none
    input  logic        serve_event,

    // Outputs
    output logic [1:0]  order_dish [0:2],   // current orders (0=empty)
    output logic [4:0]  order_timer[0:2],   // remaining seconds
    output logic        order_expired,       // pulse when order times out
    output logic        order_matched        // pulse when serve matches order
);

    // LFSR for pseudo-random dish selection (3-bit)
    logic [6:0] lfsr;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) lfsr <= 7'h5A;
        else     lfsr <= {lfsr[5:0], lfsr[6] ^ lfsr[5]};
    end

    // Map LFSR to dish 1~3
    function automatic logic [1:0] rand_dish(input logic [6:0] r);
        case (r[1:0])
            2'd0: return 2'd1; // burger
            2'd1: return 2'd2; // soup noodle
            2'd2: return 2'd3; // rice bowl
            2'd3: return 2'd1; // burger (fallback)
        endcase
    endfunction

    // New order spawn timer (spawn new order every ~8 seconds if slot available)
    logic [3:0] spawn_cnt;
    localparam SPAWN_INTERVAL = 4'd8;

    // Active order count
    logic [1:0] active_count;
    assign active_count = {1'b0, (order_dish[0] != 0)} +
                          {1'b0, (order_dish[1] != 0)} +
                          {1'b0, (order_dish[2] != 0)};

    integer i;

    always_ff @(posedge clk or posedge rst) begin
        if (rst || !game_active) begin
            for (i = 0; i < 3; i++) begin
                order_dish[i]  <= 2'd0;
                order_timer[i] <= 5'd0;
            end
            spawn_cnt     <= 0;
            order_expired <= 0;
            order_matched <= 0;
        end else begin
            order_expired <= 0;
            order_matched <= 0;

            // Tick: count down timers, spawn new orders
            if (tick_1hz) begin
                // Count timers down
                for (i = 0; i < 3; i++) begin
                    if (order_dish[i] != 2'd0) begin
                        if (order_timer[i] > 1)
                            order_timer[i] <= order_timer[i] - 1;
                        else begin
                            // Order expired
                            order_dish[i]  <= 2'd0;
                            order_timer[i] <= 5'd0;
                            order_expired  <= 1;
                        end
                    end
                end

                // Spawn new order if below max
                spawn_cnt <= spawn_cnt + 1;
                if (spawn_cnt >= SPAWN_INTERVAL - 1) begin
                    spawn_cnt <= 0;
                    if (active_count < max_orders) begin
                        // Fill only the first available slot.
                        if (max_orders > 2'd0 && order_dish[0] == 2'd0) begin
                            order_dish[0]  <= rand_dish(lfsr);
                            order_timer[0] <= order_timeout;
                        end else if (max_orders > 2'd1 && order_dish[1] == 2'd0) begin
                            order_dish[1]  <= rand_dish(lfsr);
                            order_timer[1] <= order_timeout;
                        end else if (max_orders > 2'd2 && order_dish[2] == 2'd0) begin
                            order_dish[2]  <= rand_dish(lfsr);
                            order_timer[2] <= order_timeout;
                        end
                    end
                end
            end

            // Serve matching
            if (serve_event && served_dish != 2'd0 && served_slot < 2'd3) begin
                if (order_dish[served_slot] == served_dish) begin
                    order_dish[served_slot]  <= 2'd0;
                    order_timer[served_slot] <= 5'd0;
                    order_matched            <= 1;
                end
            end
        end
    end

endmodule
