package itch_defs;

    // ITCH 5.0 Message Types
    typedef enum logic [7:0] {
        MSG_ADD_ORDER_NO_MPID = 8'h41, // 'A'
        MSG_ORDER_EXECUTED    = 8'h45  // 'E'
    } itch_msg_type_e;

    // Struct for Add Order Message (Type 'A')
    typedef struct packed {
        logic [15:0] stock_locate;
        logic [15:0] tracking_number;
        logic [47:0] timestamp;
        logic [63:0] order_reference_number;
        logic [7:0]  buy_sell_indicator; // 'B' or 'S'
        logic [31:0] shares;
        logic [31:0] stock_bytes;        // First 4 bytes of ticker for simplicity
        logic [31:0] price;              // 4 bytes integer price
    } add_order_t;

    // Struct for Order Executed Message (Type 'E')
    typedef struct packed {
        logic [15:0] stock_locate;
        logic [15:0] tracking_number;
        logic [47:0] timestamp;
        logic [63:0] order_reference_number;
        logic [31:0] executed_shares;
        logic [63:0] match_number;
    } order_executed_t;

    // Metadata passed alongside decoded orders to the Risk Engine
    typedef struct packed {
        logic        is_valid;
        logic [7:0]  msg_type;
        logic [63:0] order_id;
        logic [31:0] qty;
        logic [31:0] price;
        logic        is_sell;
    } decoded_meta_t;

endpackage: itch_defs