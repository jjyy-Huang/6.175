// TwoCycle.bsv
//
// This is a two cycle implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import MemInit::*;
import RFile::*;
import DMemory::*;
import IMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;

typedef enum {
    Fetch,
    Execute
} Stage deriving(Bits, Eq, FShow);


(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    IMemory     iMem<-mkIMemory;
    DMemory     dMem<-mkDMemory;
    CsrFile  csrf <- mkCsrFile;

    Reg#(Stage) currStage <- mkReg(Fetch);
    Reg#(DecodedInst) dInstReg <- mkRegU;

    Bool memReady = iMem.init.done && dMem.init.done;

    // TODO: complete implementation of this processor

    rule fetchStage if (csrf.started && currStage == Fetch);
        Data inst = iMem.req(pc);
        // decode
        dInstReg <= decode(inst);
        currStage <= Execute;
        $display("----------fetch stage----------");
        $display("pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
    endrule

    rule executeStage if (csrf.started && currStage == Execute);
        $display("----------execute stage----------");
        // read general purpose register values
        Data rVal1 = rf.rd1(fromMaybe(?, dInstReg.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInstReg.src2));

        // read CSR values (for CSRR inst)
        Data csrVal = csrf.rd(fromMaybe(?, dInstReg.csr));

        // execute
        ExecInst eInst = exec(dInstReg, rVal1, rVal2, pc, ?, csrVal);

        // memory
        if(eInst.iType == Ld) begin
            eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
        end else if(eInst.iType == St) begin
            let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
        end

        // check unsupported instruction at commit time. Exiting
        if(eInst.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
            $finish;
        end

        // write back to reg file
        if(isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end

        // update the pc depending on whether the branch is taken or not
        pc <= eInst.brTaken ? eInst.addr : pc + 4;

        // CSR write for sending data to host & stats
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
        currStage <= Fetch;
    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
        $display("STARTING AT PC: %h", startpc);
        pc <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

