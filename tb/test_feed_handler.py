import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallThrough
from cocotb.binary import BinaryValue

async def init_system(dut):
    """Reset routine generator"""
    dut.rst_n.value = 0
    dut.cfg_max_order_qty.value = 50000     # Configuration risk limits
    dut.cfg_max_price_sanity.value = 1000000 # Configuration upper bounds
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.s_axis_tkeep.value = 0xFF
    dut.m_axis_risk_ready.value = 1
    
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_nominal_add_order_pass(dut):
    """Validates full pipeline passing for inside-bound ITCH frames"""
    cocotb.start_soon(Clock(dut.clk, 6.4, units="ns").start()) # 156.25 MHz clock loop
    await init_system(dut)

    # Mimic 10GbE MAC delivering Raw Frame Cycle #1 (Header)
    dut.s_axis_tvalid.value = 1
    # Byte 2 contains 0x41 ('A' Message Type Indicator)
    dut.s_axis_tdata.value = 0x0000410000100005 
    dut.s_axis_tlast.value = 0
    await RisingEdge(dut.clk)

    # Cycle #2 (Payload Data Mapping matching our decoder structure parsing indices)
    # Order ID: 12345, Qty: 500, Price: 950000
    # Packing: Qty and Price structured matching SystemVerilog struct offsets
    dut.s_axis_tdata.value = (950000 << 32) | (500 << 8) | 0x42 # Buy indicator 'B'
    dut.s_axis_tlast.value = 1
    await RisingEdge(dut.clk)
    
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0

    # Wait for the 2-cycle pipelined calculation delay execution latency
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert dut.m_axis_risk_valid.value == 1, "Order should have successfully passed check conditions!"
    assert dut.m_risk_violation_drop.value == 0, "No execution drop should be present here!"

@cocotb.test()
async def test_risk_violation_drop(dut):
    """Validates wire-speed automatic dropped mitigation triggers when bounds exceed limit limits"""
    cocotb.start_soon(Clock(dut.clk, 6.4, units="ns").start())
    await init_system(dut)

    # Frame Cycle #1 
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tdata.value = 0x0000410000100005 
    await RisingEdge(dut.clk)

    # Frame Cycle #2: Enforce anomalous high quantity order (999,999 shares > 50,000 threshold limit)
    dut.s_axis_tdata.value = (950000 << 32) | (999999 << 8) | 0x42 
    dut.s_axis_tlast.value = 1
    await RisingEdge(dut.clk)
    
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert dut.m_axis_risk_valid.value == 0, "Violating frame must immediately clear from streaming pipeline output!"
    assert dut.m_risk_violation_drop.value == 1, "System hardware drop notification assertion was not detected!"