import itch_defs::*;

module risk_check (
    input  logic          clk,
    input  logic          rst_n,
    
    // Configurable Safe Bounds (static or set via AXI-lite out-of-band)
    input  logic [31:0]   cfg_max_order_qty,
    input  logic [31:0]   cfg_max_price_sanity,
    
    // Inbound metadata from Decoder
    input  decoded_meta_t s_axis_meta_data,
    input  logic          s_axis_meta_valid,
    output logic          s_axis_meta_ready,

    // Outbound metadata to Downstream Core/PCIe DMA Ring
    output decoded_meta_t m_axis_risk_data,
    output logic          m_axis_risk_valid,
    output logic          m_risk_violation_drop, // High strobe indicates malicious drop
    input  logic          m_axis_risk_ready
);

    assign s_axis_meta_ready = m_axis_risk_ready;

    // Pipeline Registers
    decoded_meta_t pipe1_data;
    logic          pipe1_valid;
    logic          pipe1_qty_fail;
    logic          pipe1_price_fail;

    // --- PIPELINE STAGE 1: Parallel Evaluation ---
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pipe1_valid      <= 1'b0;
            pipe1_qty_fail   <= 1'b0;
            pipe1_price_fail <= 1'b0;
            pipe1_data       <= '0;
        end else if (s_axis_meta_ready) begin
            pipe1_valid <= s_axis_meta_valid;
            pipe1_data  <= s_axis_meta_data;
            
            if (s_axis_meta_valid && s_axis_meta_data.is_valid) begin
                // Check Max Quantity Check
                pipe1_qty_fail   <= (s_axis_meta_data.qty > cfg_max_order_qty);
                // Check Price Sanity Limit
                pipe1_price_fail <= (s_axis_meta_data.price > cfg_max_price_sanity);
            end else begin
                pipe1_qty_fail   <= 1'b0;
                pipe1_price_fail <= 1'b0;
            end
        end
    end

    // --- PIPELINE STAGE 2: Aggregation and Hard Mitigation Strobe ---
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            m_axis_risk_valid     <= 1'b0;
            m_axis_risk_data      <= '0;
            m_risk_violation_drop <= 1'b0;
        end else if (m_axis_risk_ready) begin
            if (pipe1_valid) begin
                if (pipe1_qty_fail || pipe1_price_fail) begin
                    // Soft drop or flagged down stream pass
                    m_axis_risk_valid     <= 1'b0; // Terminate upstream routing
                    m_risk_violation_drop <= 1'b1; // Trigger hardware alert register flag
                    m_axis_risk_data      <= '0;
                end else begin
                    m_axis_risk_valid     <= 1'b1;
                    m_risk_violation_drop <= 1'b0;
                    m_axis_risk_data      <= pipe1_data;
                end
            end else begin
                m_axis_risk_valid     <= 1'b0;
                m_risk_violation_drop <= 1'b0;
            end
        end
    end

endmodule