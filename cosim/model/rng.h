#pragma once
#include <cstdint>
#include <random>
#include <vector>

class Rng {
public:
    explicit Rng(uint32_t seed) : gen(seed) {}

    uint32_t u32() { return gen(); }
    uint32_t below(uint32_t n) { return n ? gen() % n : 0; }
    uint32_t range(uint32_t lo, uint32_t hi) { return lo + below(hi - lo + 1); }
    bool chance(uint32_t percent) { return below(100) < percent; }

    template <typename T>
    T pick(const std::vector<T>& v) { return v[below((uint32_t)v.size())]; }

    template <typename T>
    void shuffle(std::vector<T>& v) {
        for (size_t i = v.size(); i > 1; i--)
            std::swap(v[i - 1], v[below((uint32_t)i)]);
    }

private:
    std::mt19937 gen;
};

inline uint32_t interesting(Rng& rng) {
    static const std::vector<uint32_t> corners = {
        0, 1, 2, 3, 4, 0xFFFFFFFF, 0xFFFFFFFE, 0x80000000, 0x7FFFFFFF, 0x80000001,
        0x0000FFFF, 0x00010000, 0xFFFF0000, 0x00008000, 31, 32, 33};
    switch (rng.below(4)) {
    case 0:  return rng.pick(corners);
    case 1:  return rng.below(64);
    case 2:  return (uint32_t)-(int32_t)rng.range(1, 64);
    default: return rng.u32();
    }
}
