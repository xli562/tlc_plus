import cocotb
from cocotb.triggers import *
from cocotb.clock import Clock
from cocotb.utils import get_sim_time
from cocotb.handle import HierarchyObject, ModifiableObject


class Testbench:
    __test__ = False  # so pytest doesn't confuse this with a test


    def __init__(self, dut:HierarchyObject, clk:ModifiableObject=None, 
                 rst:ModifiableObject=None, fail_on_checks:bool=True):
        self.dut = dut
        self.clk = clk
        self.rst = rst

        self.input_drivers = {}
        self.output_monitors = {}

        self.input_precision = [32]

        self.fail_on_checks = fail_on_checks

        if self.clk is not None:
            self.clock = Clock(self.clk, 10, units="ns")
            cocotb.start_soon(self.clock.start())


    def assign_self_params(self, attrs):
        """ Reads parameters from the DUT. Makes them 
        accessible with self.<PARAMETER_NAME>. 
        
        :param attrs: (list-like) list of parameters defined in the .sv file,
                eg ['DEPTH', 'DATA_WIDTH', 'DATA_FRAC'] 
        :return: None """

        for att in attrs:
            setattr(self, att, int(getattr(self.dut, att).value))


    async def reset(self, active_high=True):
        """ Resets the DUT by switching its reset pin. Waits 1 clock cycle 
        after each switch.
        
        :param active_high: (Optional) True if the reset pin is active-high.
        :return: None """

        if self.rst is None:
            raise Exception(
                f'Cannot find reset wire for sv module {self.dut._name}'
            )

        await RisingEdge(self.clk)
        self.rst.value = 1 if active_high else 0
        await RisingEdge(self.clk)
        self.rst.value = 0 if active_high else 1
        await RisingEdge(self.clk)


    async def initialize(self):
        await self.reset()

        # Set all monitors ready
        for monitor in self.output_monitors.values():
            monitor.ready.value = 1


    def generate_inputs(self, batches=1):
        raise NotImplementedError


    def load_drivers(self, in_tensors):
        raise NotImplementedError


    def load_monitors(self, expectation):
        raise NotImplementedError


    async def wait_end(self, timeout=1, timeout_unit="ms"):
        while True:
            await RisingEdge(self.clk)

            # ! TODO: check if this slows down test significantly
            if get_sim_time(timeout_unit) > timeout:
                raise TimeoutError("Timed out waiting for test to end.")

            if all(
                [
                    monitor.in_flight == False
                    for monitor in self.output_monitors.values()
                ]
            ):
                break

        if self.fail_on_checks:
            for driver in self.input_drivers.values():
                assert driver.send_queue.empty(), "Driver still has data to send."
