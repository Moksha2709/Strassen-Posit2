import numpy as np
from sgposit.pcposit import PCPosit

def twos_complement(bits):
    inverted = ''.join('1' if b == '0' else '0' for b in bits)
    n = int(inverted, 2) + 1
    return format(n, f'0{len(bits)}b')[-len(bits):]

def decode_posit(n, es, bits):
    if bits == '0' * n:
        return 0.0

    if bits[0] == '1':
        # Negative number: invert two's complement
        bits = twos_complement(bits)
        sign = -1
    else:
        sign = 1

    bits = bits[1:]  # drop sign bit

    # Decode regime
    i = 0
    reg_bit = bits[0] if bits else '0'
    while i < len(bits) and bits[i] == reg_bit:
        i += 1
    k = i - 1 if reg_bit == '1' else -i
    bits = bits[i + 1:]  # drop regime and terminating bit

    # Decode exponent
    exp_bits = bits[:es] if es > 0 else ''
    exp = int(exp_bits, 2) if exp_bits else 0
    bits = bits[es:]

    # Decode fraction
    frac = 0.0
    for j, bit in enumerate(bits):
        frac += int(bit) / (2 ** (j + 1))

    useed = 2 ** (2 ** es)
    value = sign * (useed ** k) * (2 ** exp) * (1 + frac)
    return value

def float_to_posit(n, es, value):
    if value == 0:
        return '0' * n

    if n < 2:
        raise ValueError("Posit size must be >= 2")

    # Handle NaR
    maxpos = 2 ** (2 ** es * (n - 2))
    if abs(value) >= maxpos or np.isnan(value) or np.isinf(value):
        return '1' + '0' * (n - 1)

    closest = None
    min_error = float('inf')

    for i in range(1, 2 ** n):  # skip 0
        b = format(i, f'0{n}b')
        decoded = decode_posit(n, es, b)
        error = abs(decoded - value)
        if error < min_error:
            min_error = error
            closest = b

    return closest


def posit_to_float(n, es, bits):
    if len(bits) != n:
        raise ValueError(f"Bitstring length must be {n}")

    # Handle special cases
    if bits == '0' * n:
        return 0.0  # Zero

    if bits == '1' + '0' * (n - 1):
        return None  # NaR (Not a Real)

    is_negative = bits[0] == '1'

    if is_negative:
        # Two's complement to get positive version
        value = (~int(bits, 2) + 1) & ((1 << n) - 1)
        bits = format(value, f'0{n}b')

    idx = 1  # Skip sign bit

    # Decode regime
    if idx >= n:
        return 0.0  # Not enough bits

    regime_sign = bits[idx]
    run_length = 0
    while idx < n and bits[idx] == regime_sign:
        run_length += 1
        idx += 1

    # Consume terminating bit
    idx += 1

    # Regime value k
    k = run_length - 1 if regime_sign == '1' else -run_length

    useed = 2 ** (2 ** es)
    regime = useed ** k

    # Decode exponent
    exp = 0
    exp_len = min(es, n - idx)
    if exp_len > 0:
        exp_bits = bits[idx:idx + exp_len]
        exp = int(exp_bits, 2)
        idx += exp_len

    # Decode fraction
    fraction = 1.0
    for i in range(n - idx):
        if idx + i < n and bits[idx + i] == '1':
            fraction += 1 / (2 ** (i + 1))

    result = regime * (2 ** exp) * fraction

    if is_negative:
        result *= -1

    return np.float32(result)

# def convertMatrixToPOSIT(A,n=8,es=1):
#     A_posit = list()
#     for i in A:
#         l = list()
#         for j in i:
#             j_posit = float_to_posit(n,es,j)
#             l.append(PCPosit(int(j_posit,2),nbits=n,es=es, mode='bits'))
#         A_posit.append(l)
#     return A_posit

def convertMatrixToPOSIT(A,n=8,es=1):
    if isinstance(A, list):
            return [convertMatrixToPOSIT(sub, n=n, es=es) for sub in A]
    else:
        j_posit = float_to_posit(n, es, A)
        return PCPosit(int(j_posit, 2), nbits=n, es=es, mode='bits')