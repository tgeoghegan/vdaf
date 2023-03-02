# Definition of IDPFs.

from __future__ import annotations
from typing import Union
from sagelib.common import \
    VERSION, \
    Bool, \
    Bytes, \
    Error, \
    Unsigned, \
    Vec, \
    gen_rand, \
    vec_add
import json
import os
import sagelib.field as field
import sagelib.prg as prg

# An Incremntal Distributed Point Function (IDPF).
class Idpf:
    # Number of keys generated by the IDPF-key generation algorithm.
    SHARES: Unsigned = None

    # Bit length of valid input values (i.e., the length of `alpha` in bits).
    BITS: Unsigned = None

    # The length of each output vector (i.e., the length of `beta_leaf` and each
    # element of `beta_inner`).
    VALUE_LEN: Unsigned = None

    # Size in bytes of each IDPF key share.
    KEY_SIZE: Unsigned = None

    # Number of random bytes consumed by the `gen()` algorithm.
    RAND_SIZE: Unsigned = None

    # The finite field used to represent the inner nodes of the IDPF tree.
    FieldInner: field.Field = None

    # The finite field used to represent the leaf nodes of the IDPF tree.
    FieldLeaf: field.Field = None

    # Generates an IDPF public share and sequence of IDPF-keys of length
    # `SHARES`. Value `alpha` is the input to encode. Values `beta_inner` and
    # `beta_leaf` are assigned to the values of the nodes on the non-zero path
    # of the IDPF tree.
    #
    # An error is raised if integer `alpha` is larger than or equal to `2^BITS`,
    # any elment of `beta_inner` has length other than `VALUE_LEN`, or if
    # `beta_leaf` has length other than `VALUE_LEN`.
    @classmethod
    def gen(Idpf,
            alpha: Unsigned,
            beta_inner: Vec[Vec[Idpf.FieldInner]],
            beta_leaf: Vec[Idpf.FieldLeaf],
            rand: Bytes[Idpf.RAND_SIZE]) -> (Bytes, Vec[Bytes]):
        raise Error('not implemented')

    # Evaluate an IDPF key at a given level of the tree and with the given set
    # of prefixes. The output is a vector where each element is a vector of
    # length `VALUE_LEN`. The output field is `FieldLeaf` if `level == BITS` and
    # `FieldInner` otherwise.
    #
    # Let `LSB(x, N)` denote the least significant `N` bits of positive integer
    # `x`. By definition, a positive integer `x` is said to be the length-`L`
    # prefix of positive integer `y` if `LSB(x, L)` is equal to the most
    # significant `L` bits of `LSB(y, BITS)`, For example, 6 (110 in binary) is
    # the length-3 prefix of 25 (11001), but 7 (111) is not.
    #
    # Each element of `prefixes` is an integer in `[0, 2^level)`. For each
    # element of `prefixes` that is the length-`level` prefix of the input
    # encoded by the IDPF-key generation algorithm (i.e., `alpha`), the sum of
    # the corresponding output shares will be equal to one of the programmed
    # output vectors (i.e., an element of `beta_inner + [beta_leaf]`). For all
    # other elements of `prefixes`, the corresponding output shares will sum up
    # to the 0-vector.
    #
    # An error is raised if any element of `prefixes` is larger than or equal to
    # `2^level` or if `level` is greater than `BITS`.
    @classmethod
    def eval(Idpf,
             agg_id: Unsigned,
             public_share: Bytes,
             key: Bytes,
             level: Unsigned,
             prefixes: Vec[Unsigned]) -> Union[Vec[Vec[Idpf.FieldInner]],
                                               Vec[Vec[Idpf.FieldLeaf]]]:
        raise Error('not implemented')

    @classmethod
    def current_field(Idpf, level):
        return Idpf.FieldInner if level < Idpf.BITS-1 \
                    else Idpf.FieldLeaf

    # Returns `True` iff `x` is the prefix of `y` of length `L`.
    @classmethod
    def is_prefix(Idpf, x: Unsigned, y: Unsigned, L: Unsigned) -> Bool:
        assert 0 < L and L <= Idpf.BITS
        return y >> (Idpf.BITS - L) == x


# Generate a set of IDPF keys and evaluate them on the given set of prefix.
def test_idpf(Idpf, alpha, level, prefixes):
    beta_inner = [[Idpf.FieldInner(1)] * Idpf.VALUE_LEN] * (Idpf.BITS-1)
    beta_leaf = [Idpf.FieldLeaf(1)] * Idpf.VALUE_LEN

    # Generate the IDPF keys.
    rand = gen_rand(Idpf.RAND_SIZE)
    (public_share, keys) = Idpf.gen(alpha, beta_inner, beta_leaf, rand)

    out = [Idpf.current_field(level).zeros(Idpf.VALUE_LEN)] * len(prefixes)
    for agg_id in range(Idpf.SHARES):
        out_share = Idpf.eval(
            agg_id, public_share, keys[agg_id], level, prefixes)
        for i in range(len(prefixes)):
            out[i] = vec_add(out[i], out_share[i])

    for (got, prefix) in zip(out, prefixes):
        #print('debug: {0:b} {1:b}: got {2}'.format(
        #    alpha, prefix, got))

        if Idpf.is_prefix(prefix, alpha, level+1):
            if level < Idpf.BITS-1:
                want = beta_inner[level]
            else:
                want = beta_leaf
        else:
            want = Idpf.current_field(level).zeros(Idpf.VALUE_LEN)

        if got != want:
            print('error: {0:b} {1:b} {2}: got {3}; want {4}'.format(
                alpha, prefix, level, got, want))


def gen_test_vec(Idpf, alpha, test_vec_instance):
    beta_inner = []
    for level in range(Idpf.BITS-1):
        beta_inner.append([Idpf.FieldInner(level)] * Idpf.VALUE_LEN)
    beta_leaf = [Idpf.FieldLeaf(Idpf.BITS-1)] * Idpf.VALUE_LEN
    rand = gen_rand(Idpf.RAND_SIZE)
    (public_share, keys) = Idpf.gen(alpha, beta_inner, beta_leaf, rand)

    printable_beta_inner = [
        [ str(elem.as_unsigned()) for elem in value ] for value in beta_inner
    ]
    printable_beta_leaf = [ str(elem.as_unsigned()) for elem in beta_leaf ]
    printable_keys = [ key.hex() for key in keys ]
    test_vec = {
        'bits': int(Idpf.BITS),
        'alpha': str(alpha),
        'beta_inner': printable_beta_inner,
        'beta_leaf': printable_beta_leaf,
        'public_share': public_share.hex(),
        'keys': printable_keys,
    }

    os.system('mkdir -p test_vec/{:02}'.format(VERSION))
    with open('test_vec/{:02}/{}_{}.json'.format(
        VERSION, Idpf.test_vec_name, test_vec_instance), 'w') as f:
        json.dump(test_vec, f, indent=4, sort_keys=True)
        f.write('\n')



# Generate a set of IDPF keys and test every possible output.
def test_idpf_exhaustive(Idpf, alpha):
    # Generate random outputs with which to program the IDPF.
    beta_inner = []
    for _ in range(Idpf.BITS - 1):
        beta_inner.append(Idpf.FieldInner.rand_vec(Idpf.VALUE_LEN))
    beta_leaf = Idpf.FieldLeaf.rand_vec(Idpf.VALUE_LEN)

    # Generate the IDPF keys.
    rand = gen_rand(Idpf.RAND_SIZE)
    (public_share, keys) = Idpf.gen(alpha, beta_inner, beta_leaf, rand)

    # Evaluate the IDPF at every node of the tree.
    for level in range(Idpf.BITS):
        #print('debug: level {0}'.format(level))
        prefixes = list(range(2^level))

        out_shares = []
        for agg_id in range(Idpf.SHARES):
            out_shares.append(
                Idpf.eval(agg_id, public_share,
                          keys[agg_id], level, prefixes))

        # Check that each set of output shares for each prefix sums up to the
        # correct value.
        for prefix in prefixes:
            got = reduce(lambda x, y: vec_add(x,y),
                map(lambda x: x[prefix], out_shares))
            #print('debug: {0:b} {1:b}: got {2}'.format(
            #    alpha, prefix, got))

            if Idpf.is_prefix(prefix, alpha, level+1):
                if level < Idpf.BITS-1:
                    want = beta_inner[level]
                else:
                    want = beta_leaf
            else:
                want = Idpf.current_field(level).zeros(Idpf.VALUE_LEN)

            if got != want:
                print('error: {0:b} {1:b} {2}: got {3}; want {4}'.format(
                    alpha, prefix, level, got, want))
