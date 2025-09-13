/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

// -----------------------------------------------------------------------------
// Tiny DMA with TinyTapeout wrapper (combined file)
// ----------------------------------------------------------------------------- 
module tt_um_dma (
    input  wire [7:0] ui_in,    // dedicated inputs -> used as cfg_in
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // IOs: input path (unused here)
    output wire [7:0] uio_out,  // IOs: output path (unused here)
    output wire [7:0] uio_oe,   // IOs: enable path (unused here)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // clock
    input  wire       rst_n     // active-low reset
);

    // Map dedicated input bus to cfg_in for the DMA
    wire [7:0] cfg_in  = ui_in;     // <-- added as you requested

    // Outputs from the DMA core
    wire [6:0] data_out;
    wire       dma_done;

    // Instantiate DMA core
    tiny_dma dma_core (
        .clk(clk),
        .rst(rst_n),      // active-low reset (your core uses negedge rst)
        .cfg_in(cfg_in),
        .data_out(data_out),
        .dma_done(dma_done)
    );

    // Pack outputs for TinyTapeout: bit7 = dma_done, bits[6:0] = data_out
    assign uo_out = {dma_done, data_out};

    // Not using bidirectional IOs in this design -> tie off
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Avoid unused warnings (reduction AND of concatenation)
    wire _unused = &{ena, uio_in, 1'b0};

endmodule


// -----------------------------------------------------------------------------
// DMA Core
// -----------------------------------------------------------------------------
module tiny_dma (
    input  wire       clk,
    input  wire       rst,       // active-low reset (neg edge in always)
    input  wire [7:0] cfg_in,    // [7]=start, [6:4]=src, [3:1]=dst, [0]=count_mode
    output reg  [6:0] data_out,  // last written 7-bit data
    output reg        dma_done   // 1-cycle done pulse
);

    // 8 words x 7 bits memory
    reg [6:0] mem [0:7];

    // internal regs
    reg [2:0] src_ptr;
    reg [2:0] dst_ptr;
    reg [2:0] words_left;
    reg [1:0] state;

    // states
    localparam IDLE     = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam DONE     = 2'b10;

    // preload demo data on reset (7-bit ASCII a–d)
    // NOTE: reset is active-low: always @(posedge clk or negedge rst)
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state      <= IDLE;
            data_out   <= 7'h00;
            dma_done   <= 1'b0;
            words_left <= 3'd0;
            src_ptr    <= 3'd0;
            dst_ptr    <= 3'd0;
            mem[0]     <= 7'h61; // "a"
            mem[1]     <= 7'h62; // "b"
            mem[2]     <= 7'h63; // "c"
            mem[3]     <= 7'h64; // "d"
            mem[4]     <= 7'h00;
            mem[5]     <= 7'h00;
            mem[6]     <= 7'h00;
            mem[7]     <= 7'h00;
        end else begin
                // default drivers (avoids undriven warnings)
          dma_done <= 1'b0;
          data_out <= data_out; // hold last value unless updated
            case (state)
                IDLE: begin
                    dma_done <= 1'b0;
                    if (cfg_in[7]) begin
                        src_ptr    <= cfg_in[6:4];
                        dst_ptr    <= cfg_in[3:1];
                        words_left <= (cfg_in[0]) ? 3 : 1; // burst=3, single=1
                        state      <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    // perform transfer: read mem[src_ptr] and write to mem[dst_ptr]
                    mem[dst_ptr] <= mem[src_ptr];  // write (register/memory update)
                    data_out     <= mem[src_ptr];  // reflect the value being written

                    src_ptr      <= src_ptr + 1;
                    dst_ptr      <= dst_ptr + 1;

                    if (words_left == 1) begin
                        // last word just handled, move to DONE next cycle
                        words_left <= 0;
                        state      <= DONE;
                        // keep dma_done low here; it will be asserted in DONE state
                        dma_done   <= 1'b0;
                    end else begin
                        words_left <= words_left - 1;
                    end
                end

                DONE: begin
                    // One-cycle pulse indicating DMA completed
                    dma_done <= 1'b1;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
