// Six stage

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import MemInit::*;
import RFile::*;
import FPGAMemory::*;
import DelayedMemory :: *;
import Decode::*;
import Exec::*;
import CsrFile::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Ehr::*;
import Btb::*;
import Scoreboard::*;


// bpred_bht
// 1967
// 1007

// bpred_j
// 2045
// 1803

// bpred_j_noloop
// 104
// 34

// Data structure for Fetch to Decode stage
typedef struct {
    Addr pc;
    Addr predPc;
    Bool epoch;
} Fetch2Decode deriving (Bits, Eq);

// Data structure for Decode to RegRead stage
typedef struct {
    Addr pc;
    Addr predPc;
    Bool epoch;
    DecodedInst dInst;
} Decode2RegRead deriving (Bits, Eq);

// Data structure for RegRead to Execute stage
typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool epoch;
    Data rVal1;
    Data rVal2;
    Data csrVal;
} RegRead2Exec deriving (Bits, Eq);

// Data structure for Execute to WriteBack

typedef struct {
    Addr pc;
    ExecInst eInst;
} Exec2WriteBack deriving (Bits, Eq);

typedef struct {
    Addr currPc;
    Addr correctPpc;
} RedirectPipe deriving (Bits, Eq);

// redirect msg from Execute stage
(* synthesize *)
module mkProc(Proc);
    Reg#(Addr)       pc <- mkReg(?);
    RFile            rf <- mkBypassRFile;
    Scoreboard#(6)   sb <- mkPipelineScoreboard;
    FPGAMemory     iMem <- mkFPGAMemory;
    FPGAMemory     dMem <- mkFPGAMemory;
    CsrFile        csrf <- mkCsrFile;
    Btb#(6)         btb <- mkBtb; // 64-entry BTB

    Reg#(Bool) fEpoch <- mkReg(False);
    Ehr#(2, Bool) gEpoch <- mkEhr(False);

    // FIFOs between stages
    FIFO#(Fetch2Decode)           f2d <- mkPipelineFIFO;
    FIFO#(Decode2RegRead)         d2r <- mkPipelineFIFO;
    FIFO#(RegRead2Exec)           r2e <- mkPipelineFIFO;
    FIFO#(Maybe#(Exec2WriteBack)) e2m <- mkPipelineFIFO;
    FIFO#(Maybe#(Exec2WriteBack)) m2w <- mkPipelineFIFO;

    FIFOF#(RedirectPipe)          rPipe <- mkBypassFIFOF;

    Bool memReady = iMem.init.done && dMem.init.done;

    rule fetchStage if (csrf.started);
        $display("[fetch] pc -> %h", pc);
        Bool currEpoch;
        Addr ppc;
        Addr currpc;
        if (rPipe.notEmpty) begin
            $display("[fetch] redirect");
            currEpoch = !fEpoch;
            fEpoch <= currEpoch;
            ppc = btb.predPc(rPipe.first.correctPpc);
            currpc = rPipe.first.correctPpc;

            btb.update(rPipe.first.currPc, rPipe.first.correctPpc);
            rPipe.deq;
        end else begin
            currEpoch = fEpoch;
            currpc = pc;
            ppc = btb.predPc(pc);
            fEpoch <= currEpoch;
        end
        iMem.req(MemReq{op: Ld, addr: currpc, data: ?});

        pc <= ppc;
        f2d.enq(Fetch2Decode{pc: currpc, predPc: ppc, epoch: currEpoch});
    endrule

    rule decodeStage;
        let x = f2d.first;
        $display("[decode] pc -> %h", x.pc);
        f2d.deq;
        let inst <- iMem.resp();
        if (gEpoch[1] == x.epoch) begin
            $display("pc: %h inst: (%h) expanded: ", x.pc, inst, showInst(inst));
            let dInst = decode(inst);
            d2r.enq(Decode2RegRead{pc: x.pc, predPc: x.predPc, epoch: x.epoch, dInst: dInst});
        end else begin
            $display("[decode] because misprediction, throw it");
        end
    endrule

    rule rfFetchStage;
        let x = d2r.first;
        let dInst = x.dInst;
        $display("[regFileFetch] pc -> %h", x.pc);
        if (gEpoch[1] == x.epoch) begin
            let hazard = (sb.search1(dInst.src1) || sb.search2(dInst.src2));
            if (!hazard) begin
                d2r.deq;
                Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
                Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
                if (isValid(dInst.src1))
                    $display("[regFileFetch] read regfile: r %d", fromMaybe(?, dInst.src1));
                if (isValid(dInst.src2))
                    $display("[regFileFetch] read regfile: r %d", fromMaybe(?, dInst.src2));
                // read CSR values (for CSRR inst)
                Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));
                r2e.enq(RegRead2Exec{
                                    pc:     x.pc,
                                    predPc: x.predPc,
                                    epoch:  x.epoch,
                                    dInst:  dInst,
                                    rVal1:  rVal1,
                                    rVal2:  rVal2,
                                    csrVal: csrVal
                                    });
                sb.insert(dInst.dst);
            end else begin
                $display("[regFileFetch] detect data hazard, stall it");
            end
        end else begin
            d2r.deq;
            $display("[regFileFetch] because misprediction, throw it");
        end
    endrule

    rule executeStage;
        let x = r2e.first;
        $display("[execute] pc -> %h", x.pc);
        r2e.deq;
        if (gEpoch[0] == x.epoch) begin
            let eInst = exec(x.dInst, x.rVal1, x.rVal2, x.pc, x.predPc, x.csrVal);

            // check unsupported instruction at commit time. Exiting
            if(eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", x.pc);
                $finish;
            end

            if (eInst.mispredict) begin
                $display("[execute] occure misprediction: pred: %h, actual: %h", x.predPc, eInst.addr);
                gEpoch[0] <= !gEpoch[0];
                rPipe.enq(RedirectPipe{currPc: x.pc, correctPpc: eInst.addr});
                // pc[0] <= eInst.addr;
                // btb.update(x.pc, eInst.addr);
            end

            e2m.enq(tagged Valid Exec2WriteBack{pc: x.pc, eInst: eInst});
        end else begin
            e2m.enq(tagged Invalid);
            $display("[execute] because misprediction, poison");
        end
    endrule

    rule memAccessStage;
        let vx = e2m.first;
        e2m.deq;
        if (vx matches tagged Valid .x) begin
            $display("[memAccess] pc -> %h", x.pc);
            if(x.eInst.iType == Ld) begin
                $display("[memAccess] load data: mem req");
                dMem.req(MemReq{op: Ld, addr: x.eInst.addr, data: ?});
            end else if(x.eInst.iType == St) begin
                $display("[memAccess] store data: mem req");
                dMem.req(MemReq{op: St, addr: x.eInst.addr, data: x.eInst.data});
            end
            m2w.enq(tagged Valid Exec2WriteBack{pc: x.pc, eInst: x.eInst});

        end else begin
            m2w.enq(tagged Invalid);
            $display("[memAccess] dont need access mem or write back, just pass the poison inst");
        end
        // memory
    endrule

    rule writeBackStage;
        let vx = m2w.first;
        m2w.deq;
        if (vx matches tagged Valid .x) begin
            $display("[writeback] pc -> %h", x.pc);
            let eInst = x.eInst;
            if(eInst.iType == Ld) begin
                $display("[writeback] load data: mem resp");
                eInst.data <- dMem.resp();
            end

            if(isValid(x.eInst.dst)) begin
                $display("[writeback] write regfile: r %d", fromMaybe(?, eInst.dst));
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end

            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);

        end else begin
            $display("[writeback] dont need write back");
        end
        sb.remove;
    endrule

    method ActionValue#(CpuToHostData) cpuToHost if(csrf.started);
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
    $display("Start cpu");
        csrf.start(0); // only 1 core, id = 0
        pc <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

