// Player Controller
// Tile-based movement on a grid
// Map is 20 tiles wide x 13 tiles tall, each tile 32x32 pixels
// Players move one tile per button press (with repeat delay)

module player_controller (
    input  logic        clk,
    input  logic        rst,
    input  logic        game_active,
    input  logic        tick_1hz,       // used for move repeat timing
    // Controls
    input  logic        move_up,
    input  logic        move_down,
    input  logic        move_left,
    input  logic        move_right,
    // Output position (tile coordinates)
    output logic [4:0]  tile_x,         // 0~19
    output logic [3:0]  tile_y,         // 0~12
    // Initial position
    input  logic [4:0]  init_x,
    input  logic [3:0]  init_y,
    // Additional tile map input to check walkability
    input  logic        tile_walkable    // 1 if target tile is walkable
);

    // Move speed: allow move every N * 100MHz cycles
    // ~150ms between moves = 15_000_000 cycles
    localparam MOVE_DELAY = 27'd15_000_000;

    logic [26:0] move_timer;

    function automatic logic map_walkable(
        input logic [4:0] x,
        input logic [3:0] y
    );
        begin
            map_walkable = 1'b1;

            // Renderer map is 20 columns x 13 rows. Only floor tiles are walkable.
            if (x >= 5'd20 || y >= 4'd13)
                map_walkable = 1'b0;
            else if (x == 5'd0 || x == 5'd19 || y == 4'd0 || y == 4'd12)
                map_walkable = 1'b0;
            else if ((x == 5'd1 && (y == 4'd1 || y == 4'd2 ||
                                    y == 4'd4 || y == 4'd5 ||
                                    y == 4'd7 || y == 4'd8)) ||
                     (y == 4'd11 && ((x >= 5'd2 && x <= 5'd3) ||
                                     (x >= 5'd5 && x <= 5'd6) ||
                                     (x >= 5'd8 && x <= 5'd9) ||
                                     (x >= 5'd11 && x <= 5'd12))) ||
                     (y == 4'd1 && (x >= 5'd4 && x <= 5'd6)) ||
                     (x == 5'd9 && (y >= 4'd1 && y <= 4'd3)) ||
                     ((x >= 5'd13 && x <= 5'd18) && (y >= 4'd1 && y <= 4'd3)) ||
                     (x == 5'd8 && y == 4'd6) ||
                     (x == 5'd18 && (y == 4'd5 || y == 4'd6)) ||
                     (x == 5'd16 && (y == 4'd8 || y == 4'd9)) ||
                     ((x >= 5'd16 && x <= 5'd18) && y == 4'd10))
                map_walkable = 1'b0;
            else if ((y == 4'd5 && (x == 5'd3 || x == 5'd4 || x == 5'd5)) ||
                     (y == 4'd8 && (x == 5'd10 || x == 5'd11 || x == 5'd12)))
                map_walkable = 1'b0;
        end
    endfunction

    // Position register
    logic [4:0] next_x;
    logic [3:0] next_y;

    always_comb begin
        next_x = tile_x;
        next_y = tile_y;
        if (move_up && tile_y > 0)
            next_y = tile_y - 1;
        else if (move_down && tile_y < 12)
            next_y = tile_y + 1;
        else if (move_left && tile_x > 0)
            next_x = tile_x - 1;
        else if (move_right && tile_x < 19)
            next_x = tile_x + 1;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || !game_active) begin
            tile_x     <= init_x;
            tile_y     <= init_y;
            move_timer <= 0;
        end else begin
            if (move_timer > 0) begin
                move_timer <= move_timer - 1;
            end else if ((move_up || move_down || move_left || move_right) &&
                         tile_walkable && map_walkable(next_x, next_y)) begin
                tile_x     <= next_x;
                tile_y     <= next_y;
                move_timer <= MOVE_DELAY;
            end
        end
    end

endmodule
