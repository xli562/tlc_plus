import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from mods.logging_mods import *
from mods.quantization_mods import *


@cocotb.test()
async def test_startup(dut):
    assert dut is not None
    