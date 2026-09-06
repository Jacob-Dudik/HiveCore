import sys
try:
    from vcdvcd import VCDVCD
except ImportError:
    print("vcdvcd not installed")
    sys.exit(1)

vcd = VCDVCD('core/top/sim/core_top.vcd')
print("Available signals:")
print([s for s in vcd.signals if 'core_top' in s][:10])
