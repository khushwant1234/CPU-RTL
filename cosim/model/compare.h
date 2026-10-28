#pragma once
#include <algorithm>
#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

struct Section {
    std::string title;
    std::vector<std::string> lines;
};

inline bool read_sections(const char* path, std::vector<Section>& out) {
    std::ifstream f(path);
    if (!f)
        return false;
    std::string line;
    while (std::getline(f, line)) {
        if (line.rfind("# ", 0) == 0)
            out.push_back({line.substr(2), {}});
        else {
            if (out.empty())
                out.push_back({"", {}});
            out.back().lines.push_back(line);
        }
    }
    return true;
}

inline void show(const char* who, const std::vector<std::string>& lines, size_t i) {
    printf("      %s: %s\n", who, i < lines.size() ? lines[i].c_str() : "(nothing, trace ended here)");
}

inline int compare(const char* label, const char* model_path, const char* rtl_path) {
    std::vector<Section> model, rtl;
    if (!read_sections(model_path, model) || !read_sections(rtl_path, rtl)) {
        printf("%-16s cannot read %s or %s\n", label, model_path, rtl_path);
        return 1;
    }

    bool by_program = !model.empty() && !model[0].title.empty();
    size_t lines = 0, bad = 0, shown = 0;
    size_t sections = std::max(model.size(), rtl.size());

    for (size_t s = 0; s < sections; s++) {
        static const Section empty;
        const Section& m = s < model.size() ? model[s] : empty;
        const Section& r = s < rtl.size() ? rtl[s] : empty;
        size_t n = std::max(m.lines.size(), r.lines.size());
        lines += m.lines.size();
        bool section_bad = false;

        for (size_t i = 0; i < n; i++) {
            bool same = i < m.lines.size() && i < r.lines.size() && m.lines[i] == r.lines[i];
            if (same)
                continue;
            section_bad = true;
            if (!by_program)
                bad++;
            if (shown < 5) {
                shown++;
                if (by_program)
                    printf("    mismatch in %s, line %zu of its trace:\n", m.title.c_str(), i + 1);
                else
                    printf("    mismatch at vector %zu:\n", i + 1);
                show("model", m.lines, i);
                show("rtl  ", r.lines, i);
                if (by_program && i > 0)
                    printf("      last matching line: %s\n", m.lines[i - 1].c_str());
            }
            if (by_program)
                break;
        }
        if (by_program && section_bad)
            bad++;
    }

    if (by_program)
        printf("%-16s %zu programs, %zu trace lines, %zu failed   %s\n", label, sections, lines, bad, bad ? "FAIL" : "PASS");
    else
        printf("%-16s %zu vectors, %zu mismatches   %s\n", label, lines, bad, bad ? "FAIL" : "PASS");
    return bad ? 1 : 0;
}
