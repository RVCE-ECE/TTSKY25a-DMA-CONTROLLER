# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_dma_single_transfer(dut):
    """Test single transfer (mode=0)"""

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Configure single transfer: start=1, src=000, dst=100, mode=0
    dut.ui_in.value = int("10001000", 2)  # 1_000_100_0
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0  # clear start

    # Wait until dma_done goes high
    while dut.uo_out.value.integer >> 7 == 0:  # bit7 is dma_done
        await ClockCycles(dut.clk, 1)

    data = dut.uo_out.value.integer & 0x7F
    dut._log.info(f"Single transfer done, data_out=0x{data:02x}")
    assert data == 0x61, "Expected first transfer to move 'a' (0x61)"


@cocotb.test()
async def test_dma_burst_transfer(dut):
    """Test burst transfer (mode=1)"""

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Configure burst transfer: start=1, src=000, dst=100, mode=1
    dut.ui_in.value = int("10001001", 2)  # 1_000_100_1
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    # Wait until dma_done goes high
    while dut.uo_out.value.integer >> 7 == 0:
        await ClockCycles(dut.clk, 1)

    data = dut.uo_out.value.integer & 0x7F
    dut._log.info(f"Burst transfer done, last data_out=0x{data:02x}")
    assert data == 0x63, "Expected last transfer to move 'c' (0x63)"
