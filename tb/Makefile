SIM ?= icarus
TOPLEVEL_LANG = verilog

VERILOG_SOURCES += $(PWD)/../rtl/itch_defs.sv
VERILOG_SOURCES += $(PWD)/../rtl/itch_decoder.sv
VERILOG_SOURCES += $(PWD)/../rtl/risk_check.sv

# Top level verification target mapping 
TOPLEVEL = risk_check
MODULE = test_feed_handler

include $(shell cocotb-config --makefiles)/Makefile.sim