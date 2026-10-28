#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include "compare.h"
#include "programs.h"
#include "simplerisc.h"
#include "vectors.h"

static const std::vector<std::string> MODULES = {"decoder", "alu", "branch_unit", "execute_stage",
                                                 "forwarding_unit", "hazard_unit", "writeback", "reg_file"};

static void usage() {
    fprintf(stderr,
            "usage:\n"
            "  cosim gen <module> <count> <seed>        random input vectors for one module\n"
            "  cosim model <module>                     run the C++ model on vectors from stdin\n"
            "  cosim programs <dir> <random> <seed>     write test programs, prints how many\n"
            "  cosim iss <dir> <count>                  run programs on the instruction set simulator\n"
            "  cosim compare <label> <model> <rtl>      compare two traces\n"
            "modules:");
    for (auto& m : MODULES)
        fprintf(stderr, " %s", m.c_str());
    fprintf(stderr, "\n");
}

static void write_program(const std::string& dir, int index, const Program& p) {
    std::string base = dir + "/prog_" + std::to_string(index);
    FILE* hex = fopen((base + ".hex").c_str(), "w");
    FILE* lst = fopen((base + ".s").c_str(), "w");
    if (!hex || !lst) {
        fprintf(stderr, "cannot write %s\n", base.c_str());
        exit(1);
    }
    fprintf(lst, "@ prog %d: %s\n", index, p.about.c_str());
    for (size_t i = 0; i < p.code.size(); i++) {
        fprintf(hex, "%08x\n", p.code[i]);
        fprintf(lst, "%04zx:  %08x   %s\n", i * 4, p.code[i], disasm(p.code[i], (uint32_t)i * 4).c_str());
    }
    fclose(hex);
    fclose(lst);
}

static std::vector<uint32_t> read_program(const std::string& path) {
    std::vector<uint32_t> code;
    FILE* f = fopen(path.c_str(), "r");
    if (!f) {
        fprintf(stderr, "cannot read %s\n", path.c_str());
        exit(1);
    }
    uint32_t word;
    while (fscanf(f, "%x", &word) == 1)
        code.push_back(word);
    fclose(f);
    return code;
}

int main(int argc, char** argv) {
    std::string cmd = argc > 1 ? argv[1] : "";

    if (cmd == "gen" && argc == 5) {
        std::string m = argv[2];
        int count = atoi(argv[3]);
        uint32_t seed = (uint32_t)atoi(argv[4]);
        for (size_t i = 0; i < MODULES.size(); i++)
            if (MODULES[i] == m)
                seed = seed * 1000003u + (uint32_t)i;
        Rng rng(seed);
        for (int i = 0; i < count; i++)
            if (!gen_vector(m, rng, stdout)) {
                usage();
                return 2;
            }
        return 0;
    }

    if (cmd == "model" && argc == 3) {
        if (!run_model(argv[2], stdin, stdout)) {
            usage();
            return 2;
        }
        return 0;
    }

    if (cmd == "programs" && argc == 5) {
        std::string dir = argv[2];
        int random_count = atoi(argv[3]);
        Rng rng((uint32_t)atoi(argv[4]));

        int index = 0;
        for (const Program& p : pair_programs(rng))
            write_program(dir, index++, p);
        RandomProgram gen(rng);
        for (int i = 0; i < random_count; i++)
            write_program(dir, index++, gen.make());
        printf("%d\n", index);
        return 0;
    }

    if (cmd == "iss" && argc == 4) {
        std::string dir = argv[2];
        int count = atoi(argv[3]);
        Coverage cov;
        for (int i = 0; i < count; i++) {
            printf("# prog %d\n", i);
            SimpleRisc cpu(read_program(dir + "/prog_" + std::to_string(i) + ".hex"));
            cpu.run(stdout, cov);
        }
        cov.report(stderr);
        return 0;
    }

    if (cmd == "compare" && argc == 5)
        return compare(argv[2], argv[3], argv[4]);

    usage();
    return 2;
}
