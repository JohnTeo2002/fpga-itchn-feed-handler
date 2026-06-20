import itch_defs::*;

module async_fifo_axis (
    input  logic          wr_clk,
    input  logic          wr_rst_n,
    input  logic          rd_clk,
    input  logic          rd_rst_n,

    // Write Port (Network Domain)
    input  decoded_meta_t s_axis_data,
    input  logic          s_axis_valid,
    output logic          s_axis_ready,

    // Read Port (System PCIe Domain)
    output decoded_meta_t m_axis_data,
    output logic          m_axis_valid,
    input  logic          m_axis_ready
);

    // Parametrized Width calculation for cross domain structural metadata
    localparam int DATA_WIDTH = $bits(decoded_meta_t);
    
    logic  [3:0] wptr_bin, wptr_gray, wptr_gray_rd_sync_0, wptr_gray_rd_sync_1;
    logic  [3:0] rptr_bin, rptr_gray, rptr_gray_wr_sync_0, rptr_gray_wr_sync_1;
    
    // Shallow 16-deep dual-port memory ring-buffer
    decoded_meta_t mem [15:0];

    // --- WRITE DOMAIN LOGIC ---
    assign s_axis_ready = ((wptr_gray[3] != rptr_gray_wr_sync_1[3]) && 
                           (wptr_gray[2] != rptr_gray_wr_sync_1[2]) && 
                           (wptr_gray[1:0] == rptr_gray_wr_sync_1[1:0])) ? 1'b0 : 1'b1;

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
        end else if (s_axis_valid && s_axis_ready) begin
            mem[wptr_bin[3:0]] <= s_axis_data;
            wptr_bin           <= wptr_bin + 1;
            wptr_gray          <= (wptr_bin + 1) ^ ((wptr_bin + 1) >> 1);
        end
    end

    // --- READ DOMAIN LOGIC ---
    assign m_axis_valid = (rptr_gray != wptr_gray_rd_sync_1);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
        end else if (m_axis_valid && m_axis_ready) begin
            rptr_bin  <= rptr_bin + 1;
            rptr_gray <= (rptr_bin + 1) ^ ((rptr_bin + 1) >> 1);
        end
    end

    assign m_axis_data = mem[rptr_bin[3:0]];

    // --- TWO-STAGE FLIP-FLOP SYNCHRONIZERS (CDC Mitigation) ---
    always_ff @(posedge rd_clk) begin
        wptr_gray_rd_sync_0 <= wptr_gray;
        wptr_gray_rd_sync_1 <= wptr_gray_rd_sync_0;
    end

    always_ff @(posedge wr_clk) begin
        rptr_gray_wr_sync_0 <= rptr_gray;
        rptr_gray_wr_sync_1 <= rptr_gray_wr_sync_0;
    end

endmodule