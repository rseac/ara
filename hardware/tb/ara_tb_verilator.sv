// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Matheus Cavalcante <matheusd@iis.ee.ethz.ch>
// Date: 21/10/2020
// Description: Top level testbench module for Verilator.

module ara_tb_verilator #(
    parameter int unsigned NrLanes = 0,
    parameter int unsigned VLEN    = 0
  )(
    input  logic        clk_i,
    input  logic        rst_ni,
    output logic [63:0] exit_o
  );

  /*****************
   *  Definitions  *
   *****************/

  localparam AxiAddrWidth     = 64;
  localparam AxiWideDataWidth = 64 * NrLanes / 2;

  /*********
   *  DUT  *
   *********/

  ara_testharness #(
    .NrLanes     (NrLanes         ),
    .VLEN        (VLEN            ),
    .AxiAddrWidth(AxiAddrWidth    ),
    .AxiDataWidth(AxiWideDataWidth)
  ) dut (
    .clk_i (clk_i ),
    .rst_ni(rst_ni),
    .exit_o(exit_o)
  );

  /*********
   *  EOC  *
   *********/

  int unsigned vector_insn_count = 0;
  int unsigned vector_load_count = 0;
  int unsigned vector_store_count = 0;
  int unsigned vector_arith_count = 0;
  int unsigned vector_cfg_count = 0;
  int unsigned vector_other_count = 0;

  logic [31:0] current_insn;
  assign current_insn = dut.i_ara_soc.i_system.i_ara.acc_req_i.acc_req.insn;

  always @(posedge clk_i) begin
    if (rst_ni) begin
      if (dut.i_ara_soc.i_system.i_ara.acc_req_i.acc_req.req_valid &&
          dut.i_ara_soc.i_system.i_ara.acc_resp_o.acc_resp.req_ready &&
          dut.cnt_en_mask) begin
        
        vector_insn_count <= vector_insn_count + 1;

        case (current_insn[6:0])
          7'b0000111: vector_load_count  <= vector_load_count + 1;
          7'b0100111: vector_store_count <= vector_store_count + 1;
          7'b1010111: begin
            if (current_insn[14:12] == 3'b111) // OPCFG
              vector_cfg_count <= vector_cfg_count + 1;
            else
              vector_arith_count <= vector_arith_count + 1;
          end
          default: vector_other_count <= vector_other_count + 1;
        endcase
      end
    end

    if (exit_o[0]) begin
      if (exit_o >> 1) begin
        $warning("Core Test ", $sformatf("*** FAILED *** (tohost = %0d)", (exit_o >> 1)));
      end else begin
        // Print hardware configuration
        $display("--------------------------------------------------");
        $display("ARA Hardware Configuration:");
        $display("  - Lanes:         %d", NrLanes);
        $display("  - VLEN:          %d bits", VLEN);
        $display("--------------------------------------------------");
        // Print vector HW runtime
        $display("[hw-cycles]: %d", int'(dut.runtime_buf_q));
        $display("[vector-instructions]: %d", vector_insn_count);
        $display("  - Arithmetic:    %d", vector_arith_count);
        $display("  - Memory Load:   %d", vector_load_count);
        $display("  - Memory Store:  %d", vector_store_count);
        $display("  - Configuration: %d", vector_cfg_count);
        if (vector_other_count > 0)
          $display("  - Others:        %d", vector_other_count);
        $info("Core Test ", $sformatf("*** SUCCESS *** (tohost = %0d)", (exit_o >> 1)));
      end

      $finish(exit_o >> 1);
    end
  end

endmodule : ara_tb_verilator
