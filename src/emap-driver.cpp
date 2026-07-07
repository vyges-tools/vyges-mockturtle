// vyges-emap — file-level multi-output technology mapping over mockturtle's emap.
//
// AIGER (+ genlib) in → mapped Verilog out (+ a stats JSON sidecar). This is the
// standalone, MIT-licensed driver mockturtle itself does not ship (emap is a
// header-only library algorithm). It mirrors OpenROAD's rmp/emap_strategy.cpp
// but at the file boundary, so a flow can interject it between synthesis and P&R.
//
// Compile-validated on ubuntu:24.04 against pinned mockturtle: reads AIGER +
// genlib, runs emap, writes mapped Verilog + a stats sidecar (verified on
// sky130.genlib + usb_funct.aig). Follow-up: preserve module/PI/PO names
// (restore_network_name / restore_pio_names_by_order) for clean OpenROAD read-back.
//
// Copyright © 2026 Vyges (https://vyges.com). All Rights Reserved. (MIT)

#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

#include <lorina/aiger.hpp>
#include <lorina/genlib.hpp>
#include <mockturtle/algorithms/emap.hpp>
#include <mockturtle/io/aiger_reader.hpp>
#include <mockturtle/io/genlib_reader.hpp>
#include <mockturtle/io/write_verilog.hpp>
#include <mockturtle/networks/aig.hpp>
#include <mockturtle/networks/block.hpp>
#include <mockturtle/utils/name_utils.hpp>
#include <mockturtle/utils/tech_library.hpp>
#include <mockturtle/views/cell_view.hpp>
#include <mockturtle/views/names_view.hpp>

namespace {

constexpr const char* kUsage =
    "vyges-emap --aig <in.aig> --genlib <tech.genlib> -o <out.v>\n"
    "           [--multioutput] [--module <name>] [--stats <stats.json>]\n"
    "\n"
    "Multi-output technology mapping (mockturtle emap). AIGER + genlib in,\n"
    "mapped Verilog out. --multioutput maps cells ABC's single-output mapper\n"
    "cannot (adders, compressors). MIT.\n";

std::string opt(int argc, char** argv, const std::string& flag) {
  for (int i = 1; i + 1 < argc; ++i)
    if (flag == argv[i]) return argv[i + 1];
  return {};
}
bool has(int argc, char** argv, const std::string& flag) {
  for (int i = 1; i < argc; ++i)
    if (flag == argv[i]) return true;
  return false;
}

}  // namespace

int main(int argc, char** argv) {
  const std::string aig_path = opt(argc, argv, "--aig");
  const std::string genlib_path = opt(argc, argv, "--genlib");
  const std::string out_path = opt(argc, argv, "-o");
  const std::string stats_path = opt(argc, argv, "--stats");
  const std::string module = opt(argc, argv, "--module");  // output module name (AIGER carries none)
  const bool multioutput = has(argc, argv, "--multioutput");

  if (aig_path.empty() || genlib_path.empty() || out_path.empty()) {
    std::fputs(kUsage, stderr);
    return 2;
  }

  // 1. genlib → tech library (9 inputs, matching OpenROAD rmp emap).
  std::vector<mockturtle::gate> gates;
  if (lorina::read_genlib(genlib_path, mockturtle::genlib_reader(gates)) !=
      lorina::return_code::success) {
    std::fprintf(stderr, "vyges-emap: cannot read genlib '%s'\n", genlib_path.c_str());
    return 1;
  }
  mockturtle::tech_library<9> lib(gates);

  // 2. AIGER → named AIG.
  mockturtle::names_view<mockturtle::aig_network> aig;
  if (lorina::read_aiger(aig_path, mockturtle::aiger_reader(aig)) !=
      lorina::return_code::success) {
    std::fprintf(stderr, "vyges-emap: cannot read AIG '%s'\n", aig_path.c_str());
    return 1;
  }

  // 3. emap → mapped multi-output cell network (proven pattern from
  //    mockturtle test/experiments + OpenROAD rmp/emap_strategy.cpp).
  mockturtle::emap_params ps;
  ps.map_multioutput = multioutput;
  mockturtle::emap_stats st;
  mockturtle::cell_view<mockturtle::block_network> res = mockturtle::emap(aig, lib, ps, &st);
  mockturtle::names_view res_named{res};

  // 3b. preserve module + PI/PO names from the input AIG so the remapped netlist
  //     reads back cleanly (needs an AIGER with a symbol table — write_aiger -symbols).
  mockturtle::restore_network_name(aig, res_named);
  mockturtle::restore_pio_names_by_order(aig, res_named);
  if (!module.empty()) {
    res_named.set_network_name(module);  // AIGER has no module name; set it explicitly
  }

  // 4. write the mapped netlist (multi-output cells → Verilog).
  mockturtle::write_verilog_with_cell(res_named, out_path);

  // 5. stats sidecar the caller reads for the before/after delta.
  if (!stats_path.empty()) {
    std::ofstream s(stats_path);
    s << "{\n"
      << "  \"schema\": \"vyges-emap-stats/1.0\",\n"
      << "  \"multioutput\": " << (multioutput ? "true" : "false") << ",\n"
      << "  \"area\": " << res.compute_area() << ",\n"
      << "  \"gates\": " << res.num_gates() << ",\n"
      << "  \"multioutput_gates\": " << st.multioutput_gates << "\n"
      << "}\n";
  }
  return 0;
}
