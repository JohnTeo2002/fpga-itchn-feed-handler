import itch_defs::*;

module itch_decoder (
    input  logic         clk,          // 156.25 MHz Network Clock
    input  logic         rst_n,
    
    // AXI4-Stream Input from 10GbE MAC
    input  logic [63:0]  s_axis_tdata,
    input  logic [7:0]   s_axis_tkeep,
    input  logic         s_axis_tvalid,
    input  logic         s_axis_tlast,
    output logic         s_axis_tready,

    // Decoded Output Meta
    output decoded_meta_t m_axis_meta_data,
    output logic          m_axis_meta_valid,
    input  logic          m_axis_meta_ready
);

    assign s_axis_tready = m_axis_meta_ready; // Backpressure pass-through

    // Internal State Machine for parsing multi-cycle streaming packets
    typedef enum logic [1:0] { IDLE, PARSE_HDR, PARSE_BODY } state_e;
    state_e state;
    
    logic [15:0] byte_cnt;
    logic [7:0]  current_msg_type;
    
    // Temporary internal buffers
    logic [63:0] r_order_id;
    logic [31:0] r_qty;
    logic [31:0] r_price;
    logic        r_is_sell;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state             <= IDLE;
            byte_cnt          <= 0;
            m_axis_meta_valid <= 1'b0;
            m_axis_meta_data  <= '0;
            current_msg_type  <= '0;
        end else begin
            m_axis_meta_valid <= 1'b0; // Default Single Cycle Strobe

            if (s_axis_tvalid && s_axis_tready) begin
                case (state)
                    
                    IDLE: begin
                        byte_cnt <= 8;
                        // Byte 0-1: Length, Byte 2: Type (bits [23:16] in little-endian 64-bit stream)
                        current_msg_type <= s_axis_tdata[23:16];
                        
                        if (s_axis_tdata[23:16] == MSG_ADD_ORDER_NO_MPID) begin
                            // TODO: Support all ITCH 5.0 message types (currently only 'A' Add Order)
                            // Missing: Order Executed ('E'), Cancel ('X'), Delete ('D'), Replace ('U'), etc.
                            state <= PARSE_BODY;
                        end else if (s_axis_tdata[23:16] == MSG_ORDER_EXECUTED) begin
                            // TODO: Implement Order Executed message parsing
                            state <= PARSE_BODY;
                        end else begin
                            // Unsupported message type - skip payload
                            state <= (s_axis_tlast) ? IDLE : PARSE_HDR;
                        end
                    end

                    PARSE_BODY: begin
                        byte_cnt <= byte_cnt + 8;
                        
                        // Ultra-low latency parsing optimized extraction logic
                        if (current_msg_type == MSG_ADD_ORDER_NO_MPID) begin
                            // NOTE: Field extraction assumes word-aligned payload from MoldUDP64.
                            // Real implementation requires multi-byte barrel shifter to handle unaligned payloads.
                            // Current bit slices are placeholder pending integration with packet realignment logic.
                            // TODO: Implement MoldUDP64 frame parsing with dynamic realignment per ITCH 5.0 spec.
                            r_order_id <= s_axis_tdata[63:0];
                            r_is_sell  <= (s_axis_tdata[7:0] == 8'h53); // 'S'
                            r_qty      <= s_axis_tdata[39:8];
                            r_price    <= s_axis_tdata[63:32];
                            
                            // Pipeline output trigger
                            m_axis_meta_valid           <= 1'b1;
                            m_axis_meta_data.is_valid   <= 1'b1;
                            m_axis_meta_data.msg_type   <= MSG_ADD_ORDER_NO_MPID;
                            m_axis_meta_data.order_id   <= s_axis_tdata[63:0];
                            m_axis_meta_data.qty        <= s_axis_tdata[39:8];
                            m_axis_meta_data.price      <= s_axis_tdata[63:32];
                            m_axis_meta_data.is_sell    <= (s_axis_tdata[7:0] == 8'h53);
                        end
                        
                        if (s_axis_tlast) state <= IDLE;
                    end

                    PARSE_HDR: begin
                        if (s_axis_tlast) state <= IDLE;
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule