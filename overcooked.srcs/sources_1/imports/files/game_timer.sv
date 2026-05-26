// Game Timer
// 180-second countdown using 100MHz clock
// Also generates 1Hz tick for other modules

module game_timer (
    input  logic        clk,        // 100MHz
    input  logic        rst,
    input  logic        start,      // begin countdown
    input  logic        pause,
    output logic [7:0]  seconds,    // 0~180
    output logic        tick_1hz,   // 1 pulse per second
    output logic        timeout,    // goes high when seconds == 0
    output logic        warn_5s     // goes high when seconds <= 5
);

    localparam CLOCK_FREQ   = 100_000_000;
    localparam GAME_SECONDS = 180;

    logic [26:0] clk_cnt;
    logic        running;

    // 1Hz tick generator
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt  <= 0;
            tick_1hz <= 0;
        end else if (running && !pause) begin
            if (clk_cnt == CLOCK_FREQ - 1) begin
                clk_cnt  <= 0;
                tick_1hz <= 1;
            end else begin
                clk_cnt  <= clk_cnt + 1;
                tick_1hz <= 0;
            end
        end else begin
            tick_1hz <= 0;
        end
    end

    // Countdown
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            seconds <= GAME_SECONDS;
            running <= 0;
        end else begin
            if (start && !running) begin
                seconds <= GAME_SECONDS;
                running <= 1;
            end else if (running && !pause && tick_1hz) begin
                if (seconds > 0)
                    seconds <= seconds - 1;
                else
                    running <= 0;
            end
        end
    end

    assign timeout = (seconds == 0);
    assign warn_5s = (seconds <= 5) && running;

endmodule
