import numpy as np
from numpy.random import uniform, random, randint
from tqdm import tqdm
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from mods.logging_mods import *
from mods.quantization_mods import *


@cocotb.test()
async def test_fifo(dut):
    """ Manual test for fifo """

    in_ports, out_ports, internal_signals = get_in_out_ports(dut)

    # Start the clock
    clock = Clock(dut.clk_i, 10, units='ns')
    cocotb.start_soon(clock.start())

    clk_count = 0
    while True:

        color_log(dut, f'===== cycle {clk_count} =====')

        # Read user input (port_index + value)
        for i in range(len(in_ports)):
            print(f'{i}: {in_ports[i]} {int(getattr(dut, in_ports[i]).value)}')
        
        while True:
            try:
                in_buf = input('>>> ')
                if in_buf == '':
                    break
                elif ',' in in_buf:
                    inputs = in_buf.split(', ')
                else:
                    inputs = [in_buf]
                for ip in inputs:
                    port, value = ip.split(' ')
                    port = in_ports[int(port.rstrip())]
                    value = int(value.lstrip())

                    # Apply inputs
                    getattr(dut, port).value = value
                break
            except:
                color_log(dut, 'invalid input, try again.')
        
        # Tick clock once
        await RisingEdge(dut.clk_i)
        clk_count += 1

        list_signals(dut)

        if input() == 'q':
            break