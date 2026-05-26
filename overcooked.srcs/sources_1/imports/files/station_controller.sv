// Station Controller
// Manages ingredient sources, chop/cook processing, assembly table, trash, and order-port serving.
// Item encoding:
//   0=none
//   1=raw beef, 2=raw lettuce, 3=bread, 4=raw noodle, 5=raw egg, 6=raw rice, 7=raw pork
//   8=cooked beef, 9=chopped lettuce, 10=cooked noodle, 11=cooked egg, 12=cooked rice, 13=cooked pork
//   14=burger, 15=soup noodle, 16=rice bowl, 17=chopped beef, 18=chopped pork
//   19=burnt food fallback, 20=burnt beef, 21=burnt pork, 22=burnt noodle, 23=burnt egg

module station_controller (
    input  logic        clk,
    input  logic        rst,
    input  logic        game_active,
    input  logic        tick_1hz,

    input  logic [2:0]  chop_required,
    input  logic [3:0]  cook_time,

    // Player 1
    input  logic [4:0]  p1_tile_x,
    input  logic [3:0]  p1_tile_y,
    input  logic        p1_interact,

    // Player 2
    input  logic [4:0]  p2_tile_x,
    input  logic [3:0]  p2_tile_y,
    input  logic        p2_interact,

    // Output: what each player is carrying
    output logic [4:0]  p1_item,
    output logic [4:0]  p2_item,

    // Current orders, used to make the bottom-right order ports dish-specific.
    input  logic [1:0]  order_dish [0:2],

    // Station display state
    output logic [4:0]  chop_display_items [0:2], // (4,1), (5,1), output at (6,1)
    output logic [4:0]  cook_display_items [0:2], // (9,1), (9,2), (9,3)
    output logic [4:0]  assembly_items  [0:9],    // (14..18,1), then (14..18,2)
    output logic [1:0]  assembly_dishes [0:5],    // (13..18,3), 1=burger 2=soup noodle 3=rice bowl

    // Output: serve event
    output logic [1:0]  served_dish,
    output logic [1:0]  served_slot,
    output logic        serve_event,

    // Sound triggers
    output logic        snd_chop,
    output logic        snd_serve
);

    localparam logic [4:0] ITEM_NONE            = 5'd0;
    localparam logic [4:0] ITEM_BEEF_RAW        = 5'd1;
    localparam logic [4:0] ITEM_LETTUCE_RAW     = 5'd2;
    localparam logic [4:0] ITEM_BREAD           = 5'd3;
    localparam logic [4:0] ITEM_NOODLE_RAW      = 5'd4;
    localparam logic [4:0] ITEM_EGG_RAW         = 5'd5;
    localparam logic [4:0] ITEM_RICE_RAW        = 5'd6;
    localparam logic [4:0] ITEM_PORK_RAW        = 5'd7;
    localparam logic [4:0] ITEM_BEEF_COOKED     = 5'd8;
    localparam logic [4:0] ITEM_LETTUCE_CHOPPED = 5'd9;
    localparam logic [4:0] ITEM_NOODLE_COOKED   = 5'd10;
    localparam logic [4:0] ITEM_EGG_COOKED      = 5'd11;
    localparam logic [4:0] ITEM_RICE_COOKED     = 5'd12;
    localparam logic [4:0] ITEM_PORK_COOKED     = 5'd13;
    localparam logic [4:0] ITEM_DISH_BURGER     = 5'd14;
    localparam logic [4:0] ITEM_DISH_NOODLE     = 5'd15;
    localparam logic [4:0] ITEM_DISH_RICE_BOWL  = 5'd16;
    localparam logic [4:0] ITEM_BEEF_CHOPPED    = 5'd17;
    localparam logic [4:0] ITEM_PORK_CHOPPED    = 5'd18;
    localparam logic [4:0] ITEM_BURNT           = 5'd19;
    localparam logic [4:0] ITEM_BEEF_BURNT      = 5'd20;
    localparam logic [4:0] ITEM_PORK_BURNT      = 5'd21;
    localparam logic [4:0] ITEM_NOODLE_BURNT    = 5'd22;
    localparam logic [4:0] ITEM_EGG_BURNT       = 5'd23;

    localparam logic [1:0] DISH_NONE       = 2'd0;
    localparam logic [1:0] DISH_BURGER     = 2'd1;
    localparam logic [1:0] DISH_NOODLE     = 2'd2;
    localparam logic [1:0] DISH_RICE_BOWL  = 2'd3;
    localparam logic [1:0] SLOT_NONE       = 2'd3;

    localparam logic [3:0] BURN_AFTER_SECONDS = 4'd10;

    logic [4:0] chop_item  [0:1];
    logic [2:0] chop_timer [0:1];
    logic       chop_busy  [0:1];
    logic       chop_done  [0:1];
    logic [4:0] chop_output_item;

    logic [4:0] cook_item       [0:2];
    logic [3:0] cook_timer      [0:2];
    logic [3:0] cook_burn_timer [0:2];
    logic       cook_busy       [0:2];
    logic       cook_done       [0:2];

    logic p1_interact_prev, p2_interact_prev;
    logic p1_interact_pulse, p2_interact_pulse;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            p1_interact_prev <= 0;
            p2_interact_prev <= 0;
        end else begin
            p1_interact_prev <= p1_interact;
            p2_interact_prev <= p2_interact;
        end
    end

    assign p1_interact_pulse = p1_interact & ~p1_interact_prev;
    assign p2_interact_pulse = p2_interact & ~p2_interact_prev;

    always_comb begin
        chop_display_items[0] = chop_item[0];
        chop_display_items[1] = chop_item[1];
        chop_display_items[2] = chop_output_item;
        cook_display_items[0] = cook_item[0];
        cook_display_items[1] = cook_item[1];
        cook_display_items[2] = cook_item[2];
    end

    function automatic logic is_adjacent(
        input logic [4:0] px, input logic [3:0] py,
        input logic [4:0] tx, input logic [3:0] ty
    );
        logic [5:0] dx, dy;
        begin
            dx = (px > tx) ? px - tx : tx - px;
            dy = (py > ty) ? py - ty : ty - py;
            return ((dx == 1 && dy == 0) || (dx == 0 && dy == 1));
        end
    endfunction

    function automatic logic at_tile(
        input logic [4:0] px, input logic [3:0] py,
        input logic [4:0] tx, input logic [3:0] ty
    );
        return (px == tx) && (py == ty);
    endfunction

    function automatic logic [4:0] ingredient_near(
        input logic [4:0] px,
        input logic [3:0] py
    );
        if (is_adjacent(px, py, 5'd1, 4'd1) ||
            is_adjacent(px, py, 5'd1, 4'd2))
            return ITEM_BEEF_RAW;
        else if (is_adjacent(px, py, 5'd1, 4'd4) ||
                 is_adjacent(px, py, 5'd1, 4'd5))
            return ITEM_LETTUCE_RAW;
        else if (is_adjacent(px, py, 5'd1, 4'd7) ||
                 is_adjacent(px, py, 5'd1, 4'd8))
            return ITEM_BREAD;
        else if (is_adjacent(px, py, 5'd2, 4'd11) ||
                 is_adjacent(px, py, 5'd3, 4'd11))
            return ITEM_NOODLE_RAW;
        else if (is_adjacent(px, py, 5'd5, 4'd11) ||
                 is_adjacent(px, py, 5'd6, 4'd11))
            return ITEM_EGG_RAW;
        else if (is_adjacent(px, py, 5'd8, 4'd11) ||
                 is_adjacent(px, py, 5'd9, 4'd11))
            return ITEM_RICE_RAW;
        else if (is_adjacent(px, py, 5'd11, 4'd11) ||
                 is_adjacent(px, py, 5'd12, 4'd11))
            return ITEM_PORK_RAW;
        else
            return ITEM_NONE;
    endfunction

    function automatic logic can_chop(input logic [4:0] item);
        return (item == ITEM_LETTUCE_RAW) ||
               (item == ITEM_BEEF_RAW)    ||
               (item == ITEM_PORK_RAW);
    endfunction

    function automatic logic [4:0] chop_result(input logic [4:0] item);
        case (item)
            ITEM_LETTUCE_RAW: return ITEM_LETTUCE_CHOPPED;
            ITEM_BEEF_RAW:    return ITEM_BEEF_CHOPPED;
            ITEM_PORK_RAW:    return ITEM_PORK_CHOPPED;
            default:          return item;
        endcase
    endfunction

    function automatic logic can_cook(input logic [4:0] item);
        return (item == ITEM_BEEF_CHOPPED) ||
               (item == ITEM_PORK_CHOPPED) ||
               (item == ITEM_NOODLE_RAW)   ||
               (item == ITEM_EGG_RAW);
    endfunction

    function automatic logic [4:0] cook_result(input logic [4:0] item);
        case (item)
            ITEM_BEEF_CHOPPED: return ITEM_BEEF_COOKED;
            ITEM_PORK_CHOPPED: return ITEM_PORK_COOKED;
            ITEM_NOODLE_RAW:   return ITEM_NOODLE_COOKED;
            ITEM_EGG_RAW:      return ITEM_EGG_COOKED;
            default:           return item;
        endcase
    endfunction

    function automatic logic is_burnt_item(input logic [4:0] item);
        return (item == ITEM_BURNT)        ||
               (item == ITEM_BEEF_BURNT)   ||
               (item == ITEM_PORK_BURNT)   ||
               (item == ITEM_NOODLE_BURNT) ||
               (item == ITEM_EGG_BURNT);
    endfunction

    function automatic logic [4:0] burn_result(input logic [4:0] item);
        case (item)
            ITEM_BEEF_COOKED:   return ITEM_BEEF_BURNT;
            ITEM_PORK_COOKED:   return ITEM_PORK_BURNT;
            ITEM_NOODLE_COOKED: return ITEM_NOODLE_BURNT;
            ITEM_EGG_COOKED:    return ITEM_EGG_BURNT;
            default:            return ITEM_BURNT;
        endcase
    endfunction

    function automatic logic can_assemble_item(input logic [4:0] item);
        return (item == ITEM_BEEF_COOKED)     ||
               (item == ITEM_LETTUCE_CHOPPED) ||
               (item == ITEM_BREAD)           ||
               (item == ITEM_NOODLE_COOKED)   ||
               (item == ITEM_EGG_COOKED)      ||
               (item == ITEM_RICE_RAW)        ||
               (item == ITEM_RICE_COOKED)     ||
               (item == ITEM_PORK_COOKED);
    endfunction

    function automatic logic [4:0] dish_to_item(input logic [1:0] dish);
        case (dish)
            DISH_BURGER:    return ITEM_DISH_BURGER;
            DISH_NOODLE:    return ITEM_DISH_NOODLE;
            DISH_RICE_BOWL: return ITEM_DISH_RICE_BOWL;
            default:        return ITEM_NONE;
        endcase
    endfunction

    function automatic logic [1:0] item_to_dish(input logic [4:0] item);
        case (item)
            ITEM_DISH_BURGER:    return DISH_BURGER;
            ITEM_DISH_NOODLE:    return DISH_NOODLE;
            ITEM_DISH_RICE_BOWL: return DISH_RICE_BOWL;
            default:             return DISH_NONE;
        endcase
    endfunction

    function automatic logic is_chop_input_access(
        input logic [4:0] px,
        input logic [3:0] py,
        input integer     slot
    );
        if (!slot)
            return at_tile(px, py, 5'd3, 4'd1) || at_tile(px, py, 5'd4, 4'd2);
        else
            return at_tile(px, py, 5'd4, 4'd2) || at_tile(px, py, 5'd5, 4'd2);
    endfunction

    function automatic logic is_chop_output_access(
        input logic [4:0] px,
        input logic [3:0] py
    );
        return at_tile(px, py, 5'd7, 4'd1) || at_tile(px, py, 5'd6, 4'd2);
    endfunction

    function automatic logic is_order_port_access(
        input logic [4:0] px,
        input logic [3:0] py,
        input integer     slot
    );
        case (slot)
            2'd0: return is_adjacent(px, py, 5'd16, 4'd10);
            2'd1: return is_adjacent(px, py, 5'd17, 4'd10);
            2'd2: return is_adjacent(px, py, 5'd18, 4'd10);
            default: return 1'b0;
        endcase
    endfunction

    logic has_beef, has_lettuce, has_bread, has_noodle, has_egg, has_rice, has_pork;
    logic recipe_burger, recipe_noodle, recipe_rice_bowl;
    logic output_has_space;

    always_comb begin
        has_beef    = 0;
        has_lettuce = 0;
        has_bread   = 0;
        has_noodle  = 0;
        has_egg     = 0;
        has_rice    = 0;
        has_pork    = 0;

        for (int j = 0; j < 10; j++) begin
            if (assembly_items[j] == ITEM_BEEF_COOKED)     has_beef    = 1;
            if (assembly_items[j] == ITEM_LETTUCE_CHOPPED) has_lettuce = 1;
            if (assembly_items[j] == ITEM_BREAD)           has_bread   = 1;
            if (assembly_items[j] == ITEM_NOODLE_COOKED)   has_noodle  = 1;
            if (assembly_items[j] == ITEM_EGG_COOKED)      has_egg     = 1;
            if (assembly_items[j] == ITEM_RICE_RAW ||
                assembly_items[j] == ITEM_RICE_COOKED)     has_rice    = 1;
            if (assembly_items[j] == ITEM_PORK_COOKED)     has_pork    = 1;
        end

        output_has_space = 0;
        for (int j = 0; j < 6; j++) begin
            if (assembly_dishes[j] == DISH_NONE)
                output_has_space = 1;
        end

        recipe_burger    = has_beef && has_lettuce && has_bread && output_has_space;
        recipe_noodle    = has_noodle && has_egg && output_has_space;
        recipe_rice_bowl = has_rice && has_pork && output_has_space;
    end

    integer i;

    always_ff @(posedge clk or posedge rst) begin : station_seq
        logic placed;
        logic made_dish;
        logic took_a, took_b, took_c;
        logic acted;
        logic output_filled;
        logic [4:0] near_item;
        logic [1:0] held_dish;

        if (rst || !game_active) begin
            for (i = 0; i < 2; i++) begin
                chop_item[i]  <= ITEM_NONE;
                chop_timer[i] <= 0;
                chop_busy[i]  <= 0;
                chop_done[i]  <= 0;
            end
            chop_output_item <= ITEM_NONE;

            for (i = 0; i < 3; i++) begin
                cook_item[i]       <= ITEM_NONE;
                cook_timer[i]      <= 0;
                cook_burn_timer[i] <= 0;
                cook_busy[i]       <= 0;
                cook_done[i]       <= 0;
            end

            for (i = 0; i < 10; i++) begin
                assembly_items[i] <= ITEM_NONE;
            end
            for (i = 0; i < 6; i++) begin
                assembly_dishes[i] <= DISH_NONE;
            end

            p1_item     <= ITEM_NONE;
            p2_item     <= ITEM_NONE;
            serve_event <= 0;
            served_dish <= DISH_NONE;
            served_slot <= SLOT_NONE;
            snd_chop    <= 0;
            snd_serve   <= 0;
        end else begin
            serve_event <= 0;
            served_dish <= DISH_NONE;
            served_slot <= SLOT_NONE;
            snd_chop    <= 0;
            snd_serve   <= 0;

            if (tick_1hz) begin
                output_filled = (chop_output_item != ITEM_NONE);
                for (i = 0; i < 2; i++) begin
                    if (chop_busy[i]) begin
                        if (chop_timer[i] > 1) begin
                            chop_timer[i] <= chop_timer[i] - 1;
                        end else begin
                            if (!output_filled) begin
                                chop_output_item <= chop_result(chop_item[i]);
                                chop_item[i]     <= ITEM_NONE;
                                chop_done[i]     <= 0;
                                output_filled    = 1;
                            end else begin
                                chop_item[i] <= chop_result(chop_item[i]);
                                chop_done[i] <= 1;
                            end
                            chop_busy[i] <= 0;
                            snd_chop     <= 1;
                        end
                    end else if (chop_done[i] && !output_filled) begin
                        chop_output_item <= chop_item[i];
                        chop_item[i]     <= ITEM_NONE;
                        chop_done[i]     <= 0;
                        output_filled    = 1;
                    end
                end

                for (i = 0; i < 3; i++) begin
                    if (cook_busy[i]) begin
                        if (cook_timer[i] > 1) begin
                            cook_timer[i] <= cook_timer[i] - 1;
                        end else begin
                            cook_item[i]       <= cook_result(cook_item[i]);
                            cook_busy[i]       <= 0;
                            cook_done[i]       <= 1;
                            cook_burn_timer[i] <= 0;
                        end
                    end else if (cook_done[i] && cook_item[i] != ITEM_NONE && !is_burnt_item(cook_item[i])) begin
                        if (cook_burn_timer[i] >= BURN_AFTER_SECONDS - 1) begin
                            cook_item[i]       <= burn_result(cook_item[i]);
                            cook_burn_timer[i] <= 0;
                        end else begin
                            cook_burn_timer[i] <= cook_burn_timer[i] + 1;
                        end
                    end
                end
            end

            // Assembly table: consume matching ingredients and place one completed dish.
            made_dish = 0;
            took_a = 0;
            took_b = 0;
            took_c = 0;

            if (recipe_burger) begin
                for (i = 0; i < 6; i++) begin
                    if (!made_dish && assembly_dishes[i] == DISH_NONE) begin
                        assembly_dishes[i] <= DISH_BURGER;
                        made_dish = 1;
                    end
                end
                if (made_dish) begin
                    for (i = 0; i < 10; i++) begin
                        if (!took_a && assembly_items[i] == ITEM_BEEF_COOKED) begin
                            assembly_items[i] <= ITEM_NONE;
                            took_a = 1;
                        end else if (!took_b && assembly_items[i] == ITEM_LETTUCE_CHOPPED) begin
                            assembly_items[i] <= ITEM_NONE;
                            took_b = 1;
                        end else if (!took_c && assembly_items[i] == ITEM_BREAD) begin
                            assembly_items[i] <= ITEM_NONE;
                            took_c = 1;
                        end
                    end
                end
            end else if (recipe_noodle) begin
                for (i = 0; i < 6; i++) begin
                    if (!made_dish && assembly_dishes[i] == DISH_NONE) begin
                        assembly_dishes[i] <= DISH_NOODLE;
                        made_dish = 1;
                    end
                end
                if (made_dish) begin
                    for (i = 0; i < 10; i++) begin
                        if (!took_a && assembly_items[i] == ITEM_NOODLE_COOKED) begin
                            assembly_items[i] <= ITEM_NONE;
                            took_a = 1;
                        end else if (!took_b && assembly_items[i] == ITEM_EGG_COOKED) begin
                            assembly_items[i] <= ITEM_NONE;
                            took_b = 1;
                        end
                    end
                end
            end else if (recipe_rice_bowl) begin
                for (i = 0; i < 6; i++) begin
                    if (!made_dish && assembly_dishes[i] == DISH_NONE) begin
                        assembly_dishes[i] <= DISH_RICE_BOWL;
                        made_dish = 1;
                    end
                end
                if (made_dish) begin
                    for (i = 0; i < 10; i++) begin
                        if (!took_a && (assembly_items[i] == ITEM_RICE_RAW ||
                                        assembly_items[i] == ITEM_RICE_COOKED)) begin
                            assembly_items[i] <= ITEM_NONE;
                            took_a = 1;
                        end else if (!took_b && assembly_items[i] == ITEM_PORK_COOKED) begin
                            assembly_items[i] <= ITEM_NONE;
                            took_b = 1;
                        end
                    end
                end
            end

            // Player 1 interactions
            if (p1_interact_pulse) begin
                acted = 0;

                if (!acted && p1_item != ITEM_NONE && is_adjacent(p1_tile_x, p1_tile_y, 5'd8, 4'd6)) begin
                    p1_item <= ITEM_NONE;
                    acted = 1;
                end

                held_dish = item_to_dish(p1_item);
                if (!acted && held_dish != DISH_NONE) begin
                    for (i = 0; i < 3; i++) begin
                        if (!acted && order_dish[i] == held_dish &&
                            is_order_port_access(p1_tile_x, p1_tile_y, i)) begin
                            serve_event <= 1;
                            served_dish <= held_dish;
                            served_slot <= i;
                            p1_item     <= ITEM_NONE;
                            snd_serve   <= 1;
                            acted       = 1;
                        end
                    end
                end

                if (!acted && p1_item == ITEM_NONE) begin
                    placed = 0;
                    for (i = 0; i < 6; i++) begin
                        if (!placed && assembly_dishes[i] != DISH_NONE &&
                            is_adjacent(p1_tile_x, p1_tile_y, 5'd13 + i, 4'd3)) begin
                            p1_item <= dish_to_item(assembly_dishes[i]);
                            assembly_dishes[i] <= DISH_NONE;
                            placed = 1;
                            acted = 1;
                        end
                    end
                end

                if (!acted && p1_item == ITEM_NONE &&
                    chop_output_item != ITEM_NONE &&
                    is_chop_output_access(p1_tile_x, p1_tile_y)) begin
                    p1_item <= chop_output_item;
                    chop_output_item <= ITEM_NONE;
                    acted = 1;
                end

                if (!acted && p1_item == ITEM_NONE) begin
                    for (i = 0; i < 3; i++) begin
                        if (!acted && cook_done[i] && cook_item[i] != ITEM_NONE &&
                            is_adjacent(p1_tile_x, p1_tile_y, 5'd9, 4'd1 + i)) begin
                            p1_item           <= cook_item[i];
                            cook_item[i]      <= ITEM_NONE;
                            cook_done[i]      <= 0;
                            cook_burn_timer[i] <= 0;
                            acted             = 1;
                        end
                    end
                end

                if (!acted && p1_item == ITEM_NONE) begin
                    near_item = ingredient_near(p1_tile_x, p1_tile_y);
                    if (near_item != ITEM_NONE) begin
                        p1_item <= near_item;
                        acted = 1;
                    end
                end

                if (!acted && can_chop(p1_item)) begin
                    for (i = 0; i < 2; i++) begin
                        if (!acted && is_chop_input_access(p1_tile_x, p1_tile_y, i) &&
                            chop_item[i] == ITEM_NONE && !chop_busy[i] && !chop_done[i]) begin
                            chop_item[i]  <= p1_item;
                            chop_timer[i] <= chop_required;
                            chop_busy[i]  <= 1;
                            chop_done[i]  <= 0;
                            p1_item       <= ITEM_NONE;
                            acted         = 1;
                        end
                    end
                end

                if (!acted && can_cook(p1_item)) begin
                    for (i = 0; i < 3; i++) begin
                        if (!acted && is_adjacent(p1_tile_x, p1_tile_y, 5'd9, 4'd1 + i) &&
                            cook_item[i] == ITEM_NONE && !cook_busy[i] && !cook_done[i]) begin
                            cook_item[i]       <= p1_item;
                            cook_timer[i]      <= cook_time;
                            cook_burn_timer[i] <= 0;
                            cook_busy[i]       <= 1;
                            cook_done[i]       <= 0;
                            p1_item            <= ITEM_NONE;
                            acted              = 1;
                        end
                    end
                end

                if (!acted && can_assemble_item(p1_item) && is_adjacent(p1_tile_x, p1_tile_y, 5'd13, 4'd1)) begin
                    placed = 0;
                    for (i = 0; i < 5; i++) begin
                        if (!placed && assembly_items[i] == ITEM_NONE) begin
                            assembly_items[i] <= p1_item;
                            p1_item <= ITEM_NONE;
                            placed = 1;
                            acted = 1;
                        end
                    end
                end else if (!acted && can_assemble_item(p1_item) && is_adjacent(p1_tile_x, p1_tile_y, 5'd13, 4'd2)) begin
                    placed = 0;
                    for (i = 5; i < 10; i++) begin
                        if (!placed && assembly_items[i] == ITEM_NONE) begin
                            assembly_items[i] <= p1_item;
                            p1_item <= ITEM_NONE;
                            placed = 1;
                            acted = 1;
                        end
                    end
                end
            end

            // Player 2 interactions
            if (p2_interact_pulse) begin
                acted = 0;

                if (!acted && p2_item != ITEM_NONE && is_adjacent(p2_tile_x, p2_tile_y, 5'd8, 4'd6)) begin
                    p2_item <= ITEM_NONE;
                    acted = 1;
                end

                held_dish = item_to_dish(p2_item);
                if (!acted && held_dish != DISH_NONE) begin
                    for (i = 0; i < 3; i++) begin
                        if (!acted && order_dish[i] == held_dish &&
                            is_order_port_access(p2_tile_x, p2_tile_y, i)) begin
                            serve_event <= 1;
                            served_dish <= held_dish;
                            served_slot <= i;
                            p2_item     <= ITEM_NONE;
                            snd_serve   <= 1;
                            acted       = 1;
                        end
                    end
                end

                if (!acted && p2_item == ITEM_NONE) begin
                    placed = 0;
                    for (i = 0; i < 6; i++) begin
                        if (!placed && assembly_dishes[i] != DISH_NONE &&
                            is_adjacent(p2_tile_x, p2_tile_y, 5'd13 + i, 4'd3)) begin
                            p2_item <= dish_to_item(assembly_dishes[i]);
                            assembly_dishes[i] <= DISH_NONE;
                            placed = 1;
                            acted = 1;
                        end
                    end
                end

                if (!acted && p2_item == ITEM_NONE &&
                    chop_output_item != ITEM_NONE &&
                    is_chop_output_access(p2_tile_x, p2_tile_y)) begin
                    p2_item <= chop_output_item;
                    chop_output_item <= ITEM_NONE;
                    acted = 1;
                end

                if (!acted && p2_item == ITEM_NONE) begin
                    for (i = 0; i < 3; i++) begin
                        if (!acted && cook_done[i] && cook_item[i] != ITEM_NONE &&
                            is_adjacent(p2_tile_x, p2_tile_y, 5'd9, 4'd1 + i)) begin
                            p2_item           <= cook_item[i];
                            cook_item[i]      <= ITEM_NONE;
                            cook_done[i]      <= 0;
                            cook_burn_timer[i] <= 0;
                            acted             = 1;
                        end
                    end
                end

                if (!acted && p2_item == ITEM_NONE) begin
                    near_item = ingredient_near(p2_tile_x, p2_tile_y);
                    if (near_item != ITEM_NONE) begin
                        p2_item <= near_item;
                        acted = 1;
                    end
                end

                if (!acted && can_chop(p2_item)) begin
                    for (i = 0; i < 2; i++) begin
                        if (!acted && is_chop_input_access(p2_tile_x, p2_tile_y, i) &&
                            chop_item[i] == ITEM_NONE && !chop_busy[i] && !chop_done[i]) begin
                            chop_item[i]  <= p2_item;
                            chop_timer[i] <= chop_required;
                            chop_busy[i]  <= 1;
                            chop_done[i]  <= 0;
                            p2_item       <= ITEM_NONE;
                            acted         = 1;
                        end
                    end
                end

                if (!acted && can_cook(p2_item)) begin
                    for (i = 0; i < 3; i++) begin
                        if (!acted && is_adjacent(p2_tile_x, p2_tile_y, 5'd9, 4'd1 + i) &&
                            cook_item[i] == ITEM_NONE && !cook_busy[i] && !cook_done[i]) begin
                            cook_item[i]       <= p2_item;
                            cook_timer[i]      <= cook_time;
                            cook_burn_timer[i] <= 0;
                            cook_busy[i]       <= 1;
                            cook_done[i]       <= 0;
                            p2_item            <= ITEM_NONE;
                            acted              = 1;
                        end
                    end
                end

                if (!acted && can_assemble_item(p2_item) && is_adjacent(p2_tile_x, p2_tile_y, 5'd13, 4'd1)) begin
                    placed = 0;
                    for (i = 0; i < 5; i++) begin
                        if (!placed && assembly_items[i] == ITEM_NONE) begin
                            assembly_items[i] <= p2_item;
                            p2_item <= ITEM_NONE;
                            placed = 1;
                            acted = 1;
                        end
                    end
                end else if (!acted && can_assemble_item(p2_item) && is_adjacent(p2_tile_x, p2_tile_y, 5'd13, 4'd2)) begin
                    placed = 0;
                    for (i = 5; i < 10; i++) begin
                        if (!placed && assembly_items[i] == ITEM_NONE) begin
                            assembly_items[i] <= p2_item;
                            p2_item <= ITEM_NONE;
                            placed = 1;
                            acted = 1;
                        end
                    end
                end
            end
        end
    end

endmodule
