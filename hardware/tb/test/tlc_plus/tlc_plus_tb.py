import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_tlc_plus(dut):
    """ Simple test of tlc_plus:
      1. Reset
      2. Observe we start in VEH_PASS
      3. Pulse reqn_i
      4. Wait for the FSM to move through all states (pass -> slow -> stop -> ped_pass -> pass)

      Does not test for 7-segment display readout.
    """
    # Start the clock
    clock = Clock(dut.clk_i, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rstn_i.value = 0
    dut.reqn_i.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    await RisingEdge(dut.clk_i)

    for _ in range(2):
        # Apply inputs
        dut.reqn_i.value = 0
        await RisingEdge(dut.clk_i)
        dut.reqn_i.value = 1

        assert dut.fsm_0.state.value == 0, 'should be in state VEH_PASS'
        
        while dut.fsm_0.state.value != 1:
            await RisingEdge(dut.clk_i)
        assert dut.fsm_0.state.value == 1, 'should be in state VEH_SLOW'

        while dut.fsm_0.state.value != 2:
            await RisingEdge(dut.clk_i)
        assert dut.fsm_0.state.value == 2, 'should be in state VEH_STOP'

        while dut.fsm_0.state.value != 3:
            await RisingEdge(dut.clk_i)
        assert dut.fsm_0.state.value == 3, 'should be in state PED_PASS'

        while dut.fsm_0.state.value != 0:
            await RisingEdge(dut.clk_i)
        assert dut.fsm_0.state.value == 0, 'should be in state VEH_PASS'
