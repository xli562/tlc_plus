# Testbench Developers' Guide

## Testbench code structure

The following draws example from `terminate_tb.py` in branch `vru`, commit `f967d8d09014a1d5a388ed3e25b5a8bf46c18f09`. Every line (excluding some newlines) of the original code can be found below, in sequence.  

_There is also a simple manual testbench (`hardware/tb/manual_tb.py`) if you want to manually tick the clock by pressing `ENTER` keys. The code should be short and self-explaniroty._

1. Import modules

    ```python
    from tqdm import tqdm
    from numpy.random import random, uniform
    import cocotb
    from cocotb.clock import Clock
    from cocotb.triggers import RisingEdge

    from mods.logging_mods import *
    from mods.quantization_mods import *
    ```

    Consider deleting unused modules for tidy code.

2. Test-function name and docstring

    ```python
    @cocotb.test()
    async def test_transm_compute(dut):
        """ Randomized test for alpha_times_T_o and transm_flag_o """
    ```

    - Test-function name should start with 'test', be descriptive and not too long. E.g., `test_transm_compute` is better than `random_test_transmittance_compute`
    - The docstring should include the signals being tested, e.g., "Randomized test for `alpha_times_T_o` and `transm_flag_o`"

3. Specify test iterations and log start of test

    ```python
    test_iters = 10000        # TUNABLE: = '50', trades test robustness for speed
    color_log(dut, f'Running test_transm_compute() with test_iters = {test_iters}')
    ```

    `color_log()` uses [colorama](https://pypi.org/project/colorama/) to enable logging in color. Strongly recommended alternative to `print()` and `dut._log()`. It also does certain auto-formatting. For example, it highlights `Running test_transm_compute() ...` in yellow. The code to do this is very simple. Please refer to `hardware/tb/mods/logging_mods.py`.

4. Read / calculate parameters from the DUT

    ```python
    # Read parameters from the DUT
    ALPHA_WIDTH = int(dut.ALPHA_WIDTH.value)
    ALPHA_FRAC = int(dut.ALPHA_FRAC.value)
    TRANSM_WIDTH = int(dut.TRANSM_WIDTH.value)
    TRANSM_FRAC = int(dut.TRANSM_FRAC.value)
    TRANSM_THRESHOLD = int(dut.TRANSM_THRESHOLD.value)
    CALC_LATENCY = int(dut.CALC_LATENCY.value)
    ALPHA_THRESHOLD_SHIFT = int(dut.ALPHA_THRESHOLD_SHIFT.value)
    ALPHA_THRESHOLD = 2**(-ALPHA_THRESHOLD_SHIFT)
    ```

    Type conversion (`int()` etc.) is recommended to avoid unexpected behaviour.

5. Specify numerical thresholds

    ```python
    # TUNABLE: tolerance for quantization error. You probably want to 
    # plot rel_err to check for optimum quantization
    rel_err_threshold = 0.2
    abs_err_threshold = 1 / TRANSM_THRESHOLD
    ```

    In this case, the test would fail if (absolute error > `abs_err_threshold`) and (relative error > `rel_err_threshold`).  
    Relative / absolute error is always abbreviated as 'rel_err' / 'abs_err'.  

6. Start the clock

    ```python
    # Start the clock
    clock = Clock(dut.clk_i, 10, units='ns')
    cocotb.start_soon(clock.start())
    ```

    For safety, always use `10` for period and `'ns'` for unit, unless you have very good reasons to do otherwise.

7. Reset the DUT

    ```python
    # Reset the DUT
    dut.resetn_i.value = 0
    dut.valid_i.value = 0
    dut.ready_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.resetn_i.value = 1
    await RisingEdge(dut.clk_i)
    ```

    For safety, `valid_i` and `ready_i` are also reset, although deleting the 2 lines makes no apparant difference to test results.

8. Reset simulated variables (as opposed to the DUT's variables) and start the main loop

    ```python
    # Main test for-loop
    transm_flag_o_sim = 0
    clk_count = 0
    accu_rel_err_lst = [0.]
    T_1_sim = T_0_sim = alpha_times_T_o_sim = 0
    for test_count in tqdm(range(test_iters)):
    ```

9. Generate testcase

    ```python
    # Generate testcase (floats get converted to fixed-points)
    randfloat = random()
    if randfloat < 0.8:
        alpha_value_i_sim = uniform(ALPHA_THRESHOLD, 1.0)
    elif randfloat < 0.99:
        alpha_value_i_sim = uniform(0, ALPHA_THRESHOLD)
    else:
        alpha_value_i_sim = 1
    alpha_flag_i_sim = int(alpha_value_i_sim >= ALPHA_THRESHOLD)
    ```

    Use a few different sets of constant testcases at the early stage of testing:

    ```python
    alpha_value_i_sim = 0.5
    alpha_flag_i_sim = 1

    alpha_value_i_sim = 0.001
    alpha_flag_i_sim = 1

    alpha_value_i_sim = 0.8
    alpha_flag_i_sim = 0
    ```

    etc., as deterministic bugs that recur every time are easier to fix.  

    If there are input flags that changes the workings of the DUT (e.g. early termination), consider splitting the testcases according to the flag's value. In this way, you'll be debugging one type of bugs (e.g. end-value related) first before moving on to the next type (e.g. incorrect early termination).  

    Don't try edge cases straight away. Move from easy cases to edge-cases. Move to random testcases only when all above bugs are (more or less) fixed.  

    Record the generated random testcases (e.g. in console logging). If a test fails, don't re-run with other random testcases. Apply the recorded testcase deterministically, and bugs will be recurrent, thus easier to fix.

    N.B. An alternative is to seed the random module, but I have less testing experience with this.

10. Calculate expected output

    ```python
    # Calculate expected output
    if alpha_flag_i_sim:
        T_0_sim = 1.0 if clk_count == 0 else T_1_sim
        alpha_times_T_o_sim = T_0_sim * alpha_value_i_sim
        T_1_sim = T_0_sim - alpha_times_T_o_sim
    ```

    Try to get this part correct when first writing the testbench. Bugs frequently come from this stage.

11. Apply the generated testcase to the DUT input pins

    ```python
    # Apply inputs
    while not dut.ready_o.value:
        await RisingEdge(dut.clk_i)
    dut.alpha_value_i.value = float_to_fixed_point(alpha_value_i_sim, ALPHA_WIDTH, ALPHA_FRAC)
    dut.alpha_flag_i.value = alpha_flag_i_sim

    # Indicate valid input data
    dut.valid_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.valid_i.value = 0
    ```

    The handshake protocol. Data will only flow from the previous stage to the next stage if:
    1. The next stage indicates readiness to receive data (via `ready_o`), and
    2. The previous stage indicates validness of the data present on the bus (via `valid_i`).

12. Wait for the DUT to compute

    ```python
    if alpha_flag_i_sim:
        # Wait for DUT to compute
        while not dut.valid_o.value:
            await RisingEdge(dut.clk_i)
    else:
        # Check that valid_o is not high
        for _ in range(CALC_LATENCY * 2):
            assert not int(dut.valid_o.value), 'valid_o is 1 when alhpa_flag_i is 0'
    ```

    Computation usually takes some cycles to complete. When computation is complete (ie the DUT is at state `OUTPUT`, in this case), `valid_o` will be asserted.  

    This step will cause dead loops if `valid_o` is never found to be asserted.  

    There are often non-trivial testcases where `valid_o` would remain low. For example, in this case, `valid_o` should remain low if `alpha_flag_i` is low (i.e., alpha < threshold). If the simulated alpha flag is low, we do not wait for `valid_o` to become high, but instead check that it is low for `CALC_LATENCY * 2` cycles.

13. Read output values from the DUT output pins

    ```python
    # Indicate ready to accept result
    dut.ready_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.ready_i.value = 0

    # Read values from the DUT
    T_0_dut = fixed_point_to_float(dut.T_0.value, TRANSM_WIDTH, TRANSM_FRAC, signed=False)
    T_1_dut = fixed_point_to_float(dut.T_1.value, TRANSM_WIDTH, TRANSM_FRAC, signed=False)
    alpha_times_T_o_dut = fixed_point_to_float(
        dut.alpha_times_T_o.value, 
        ALPHA_WIDTH + TRANSM_WIDTH, 
        ALPHA_FRAC + TRANSM_FRAC,
        signed=False
    )
    transm_flag_o_sim = 1 if T_1_dut > (1.0 / TRANSM_THRESHOLD) else 0
    transm_flag_o_dut = int(dut.transm_flag_o.value)
    ```

    - In cases where `valid_o == 1`, as per the handshake protocol, `ready_i` need to be asserted to simulate a read operation from the next module. Then we read and store the DUT's output to python variables in the testbench. We can also read and store other intermediate signals in the DUT - this provides a more consice way to debug, instead of waveform-staring.
    - In cases where `valid_o == 0`, the values will still be read and stored, but discrepancy with simulated values are ignored, as per the next stage:

14. Compare the DUT's output with expected values

    ```python
    # Compare with expected values
    alpha_times_T_rel_err = float(abs(relative_error(alpha_times_T_o_dut, alpha_times_T_o_sim)))
    alpha_times_T_abs_err = alpha_times_T_o_sim - alpha_times_T_o_dut
    is_err_large = (alpha_times_T_abs_err > abs_err_threshold) and (alpha_times_T_rel_err > rel_err_threshold)
    is_transm_flag_mismatch = (transm_flag_o_dut != transm_flag_o_sim)
    if int(dut.valid_o.value) and (is_transm_flag_mismatch or (transm_flag_o_sim and is_err_large)):
        color_log(dut, f'\n\n===== Iter {test_count} =====', log_error=True)
        color_log(dut, f'Input alpha_flag_i: {alpha_flag_i_sim}')
        color_log(dut, f'Input alpha_value_i: {alpha_value_i_sim}')
        color_log(dut, f'')
        color_log(dut, f'Output T_0 {T_0_dut}')
        color_log(dut, f'Expted T_0 {T_0_sim}')
        color_log(dut, f'Output T_1 {T_1_dut}')
        color_log(dut, f'Expted T_1 {T_1_sim}')
        color_log(dut, f'Output alpha_times_T_o {alpha_times_T_o_dut}', log_error=is_err_large)
        color_log(dut, f'Expted alpha_times_T_o {alpha_times_T_o_sim}', log_error=is_err_large)
        color_log(dut, f'Relerr (accurate) {alpha_times_T_rel_err*100} %', log_error=is_err_large)
        color_log(dut, f'Output transm_flag_o {transm_flag_o_dut}', log_error=is_transm_flag_mismatch)
        color_log(dut, f'Expted transm_flag_o {transm_flag_o_sim}')
        assert False
        # breakpoint()      # Use when debugging
    ```

    Small values will often produce large (eg 60% - 200%) relative errors, due to numerical instability. Therefore, the error is only considered 'large' if (abs_err > `abs_err_threshold`) _and_ (rel_err > `rel_err_threshold`).

    Flag mismatch is also checked.

    For debugging, it is useful to always log the inputs, outputs and/or relative errors. This is often more efficient than using waveforms. The WaveTrace plugin requires manually adding signals whenever a `.vcd` file is opened. Console logging forces you to select the most important signals to analyse, displays output and expected values side-by-side, and preserves history of every run.

    When debugging, use `breakpoint()` instead of `assert False` in order to inspect variables.

15. Ending the test-round

    ```python
    # Record relative error if T_1 > threshold
    if alpha_flag_i_sim and transm_flag_o_sim:
        clk_count += 1
        accu_rel_err_lst.append(alpha_times_T_rel_err)
    elif not transm_flag_o_sim:
        # Reset DUT and simulated variables if transmittance flag is cleared
        clk_count = 0
        dut.resetn_i.value = 0
        dut.valid_i.value = 0
        dut.ready_i.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk_i)
        dut.resetn_i.value = 1
        await RisingEdge(dut.clk_i)
    ```

    Record the relative error if it's valid.

    Resets the DUT if transmittance flag is low (ie early termination happens). Note that the code has already checked for transmittance flag mismatch in the previous stages.

    Variables are reset, `test_count` increments by 1, and a new test-round is started until another early-termination (or until `test_iters` test-rounds are preformed)

16. Ending the test

    ```python
    accu_rel_err_lst.sort(reverse=True)
    color_log(dut, f'\n`alpha_times_T_o` max relative error:')
    color_log(dut, f'- accurate {round(accu_rel_err_lst[0]*100, 2)} %')
    ```

    If no error is raised during the test, the test ends successfully. The code finds the maximum relative error and logs it in the console.

    The `accu_` prefix means that `alpha_times_T_o_sim` is accurately calculated using python float operations, instead of a simulation of quantized computation.
