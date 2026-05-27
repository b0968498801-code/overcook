// Buzzer Controller
// Generates five audible sound effects with a passive piezo buzzer.
// Effects:
//   game start      -> ascending start sound
//   chop complete   -> short prompt sound
//   serve success   -> rising success sound
//   last 5 seconds  -> warning double beep
//   game over       -> descending ending sound
// 幹你媽逼
module buzzer (
    input  logic        clk,          // 100MHz
    input  logic        rst,
    input  logic        snd_start,    // pulse: game start
    input  logic        snd_chop,     // pulse: chop done
    input  logic        snd_serve,    // pulse: successful serve
    input  logic        snd_warn,     // pulse: countdown warning
    input  logic        snd_gameover, // pulse: game over
    output logic        buzzer_out
);

    typedef enum logic [2:0] {
        E_NONE,
        E_START,
        E_CHOP,
        E_SERVE,
        E_WARN,
        E_GAMEOVER
    } effect_t;

    effect_t effect;

    logic [2:0]  note_idx;
    logic [15:0] note_ms;
    logic [16:0] ms_cnt;
    logic        ms_tick;
    logic [31:0] tone_cnt;

    function automatic logic [31:0] half_period(input int freq_hz);
        if (freq_hz <= 0)
            return 32'd0;
        else
            return 100_000_000 / (2 * freq_hz);
    endfunction

    function automatic logic [2:0] note_count(input effect_t e);
        case (e)
            E_START:    return 3'd3;
            E_CHOP:     return 3'd1;
            E_SERVE:    return 3'd3;
            E_WARN:     return 3'd3;
            E_GAMEOVER: return 3'd3;
            default:    return 3'd0;
        endcase
    endfunction

    function automatic logic [15:0] note_duration(input effect_t e, input logic [2:0] n);
        case (e)
            E_START: begin
                case (n)
                    3'd0:    return 16'd90;
                    3'd1:    return 16'd90;
                    default: return 16'd160;
                endcase
            end
            E_CHOP: return 16'd120;
            E_SERVE: begin
                case (n)
                    3'd0:    return 16'd90;
                    3'd1:    return 16'd90;
                    default: return 16'd180;
                endcase
            end
            E_WARN: begin
                case (n)
                    3'd0:    return 16'd80;
                    3'd1:    return 16'd70;  // silence gap
                    default: return 16'd80;
                endcase
            end
            E_GAMEOVER: begin
                case (n)
                    3'd0:    return 16'd180;
                    3'd1:    return 16'd220;
                    default: return 16'd420;
                endcase
            end
            default: return 16'd1;
        endcase
    endfunction

    function automatic logic [31:0] note_half_period(input effect_t e, input logic [2:0] n);
        case (e)
            E_START: begin
                case (n)
                    3'd0:    return half_period(523);  // C5
                    3'd1:    return half_period(659);  // E5
                    default: return half_period(784);  // G5
                endcase
            end
            E_CHOP: return half_period(988);           // B5
            E_SERVE: begin
                case (n)
                    3'd0:    return half_period(659);  // E5
                    3'd1:    return half_period(880);  // A5
                    default: return half_period(1175); // D6
                endcase
            end
            E_WARN: begin
                case (n)
                    3'd0:    return half_period(988);  // B5
                    3'd1:    return 32'd0;             // silence
                    default: return half_period(988);  // B5
                endcase
            end
            E_GAMEOVER: begin
                case (n)
                    3'd0:    return half_period(392);  // G4
                    3'd1:    return half_period(330);  // E4
                    default: return half_period(262);  // C4
                endcase
            end
            default: return 32'd0;
        endcase
    endfunction

    // 1 ms tick
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ms_cnt  <= 0;
            ms_tick <= 0;
        end else if (ms_cnt == 17'd99_999) begin
            ms_cnt  <= 0;
            ms_tick <= 1;
        end else begin
            ms_cnt  <= ms_cnt + 1;
            ms_tick <= 0;
        end
    end

    // Effect sequencer. Game over can interrupt any currently playing sound.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            effect   <= E_NONE;
            note_idx <= 0;
            note_ms  <= 0;
        end else begin
            if (snd_gameover && effect != E_GAMEOVER) begin
                effect   <= E_GAMEOVER;
                note_idx <= 0;
                note_ms  <= 0;
            end else if (effect == E_NONE) begin
                note_idx <= 0;
                note_ms  <= 0;

                if (snd_serve)
                    effect <= E_SERVE;
                else if (snd_start)
                    effect <= E_START;
                else if (snd_chop)
                    effect <= E_CHOP;
                else if (snd_warn)
                    effect <= E_WARN;
            end else if (ms_tick) begin
                if (note_ms >= note_duration(effect, note_idx) - 1) begin
                    note_ms <= 0;
                    if (note_idx >= note_count(effect) - 1) begin
                        effect   <= E_NONE;
                        note_idx <= 0;
                    end else begin
                        note_idx <= note_idx + 1;
                    end
                end else begin
                    note_ms <= note_ms + 1;
                end
            end
        end
    end

    // Square wave tone generator. A zero half-period means silence.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tone_cnt   <= 0;
            buzzer_out <= 0;
        end else if (effect == E_NONE || note_half_period(effect, note_idx) == 0) begin
            tone_cnt   <= 0;
            buzzer_out <= 0;
        end else if (tone_cnt >= note_half_period(effect, note_idx) - 1) begin
            tone_cnt   <= 0;
            buzzer_out <= ~buzzer_out;
        end else begin
            tone_cnt <= tone_cnt + 1;
        end
    end

endmodule
