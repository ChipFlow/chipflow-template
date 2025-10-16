from amaranth import Module, Signal
from amaranth.lib import wiring

__all__ = ["MySoC"]

class MySoC(wiring.Component):
    """Minimal SoC for cache warming - just a dummy module with a signal"""
    def __init__(self):
        super().__init__({})

    def elaborate(self, platform):
        m = Module()

        # Just add a dummy signal so we have something to elaborate
        dummy = Signal(name="dummy")
        m.d.comb += dummy.eq(1)

        return m
