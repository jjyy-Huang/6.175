// TwoStageBTB.bsv
//
// This is a two stage pipelined (with BTB) implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import MemInit::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import FIFO::*;
import SpecialFIFOs::*;
import Ehr::*;
import Btb::*;

// Data structure for Fetch to Execute stage
typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool epoch;
} F2E deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    Ehr#(2, Addr) pcReg <- mkEhr(?);
    RFile            rf <- mkRFile;
    IMemory        iMem <- mkIMemory;
    DMemory        dMem <- mkDMemory;
    CsrFile        csrf <- mkCsrFile;
    Btb#(8)         btb <- mkBtb;

    // FIFO between two stages
    FIFO#(F2E) f2eFifo <- mkFIFO;
    Ehr#(2, Bool) epochG <- mkEhr(False);

    Bool memReady = iMem.init.done && dMem.init.done;

    // TODO: complete implementation of this processor

    rule fcStage if (csrf.started);
        $display("----------fetch stage----------");
        let ppc = btb.predPc(pcReg[0]);
        pcReg[0] <= ppc;
        let inst = iMem.req(pcReg[0]);
        let dInst = decode(inst);

        $display("pc: %h inst: (%h) expanded: ", pcReg[0], inst, showInst(inst));
        f2eFifo.enq(F2E{
                        pc:     pcReg[0],
                        predPc: ppc,
                        dInst:  dInst,
                        epoch:  epochG[0]});
    endrule

    rule exStage if (csrf.started);
        $display("----------execute stage----------");
        let exPc   = f2eFifo.first.pc;
        let exPpc  = f2eFifo.first.predPc;
        let dInst  = f2eFifo.first.dInst;
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        let epoch  = f2eFifo.first.epoch;
        // read CSR values (for CSRR inst)
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));
        f2eFifo.deq;
        $display("pc: %h ", exPc);

        if (epoch == epochG[1]) begin
            let eInst = exec(dInst, rVal1, rVal2, exPc, exPpc, csrVal);
            if (eInst.mispredict) begin
                $display("wrong prediction, fix it ----- rediction and thron next inst where is loaded in f2efifo.");
                pcReg[1] <= eInst.addr;
                epochG[1] <= !epochG[1];
            end

            if (eInst.brTaken) begin
                btb.update(exPc, eInst.addr);
            end

            // memory
            if (eInst.iType == Ld) begin
                eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
            end else if (eInst.iType == St) begin
                let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
            end

            // check unsupported instruction at commit time. Exiting
            if (eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", exPc);
                $finish;
            end

            // write back to reg file
            if (isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end

            // CSR write for sending data to host & stats
            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
        end else begin
            $display("error fecthed inst, just throw it.");
        end
    endrule


    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
        $display("Start at pc 200\n");
        $fflush(stdout);
        pcReg[0] <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

