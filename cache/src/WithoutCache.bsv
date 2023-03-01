import ProcTypes::*;
import Types::*;
import RFile::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Fifo::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Ehr::*;
import Btb::*;
import Scoreboard::*;
import Bht::*;
import Vector::*;
import Ras::*;

import MemUtil::*;
import Memory::*;
import MemTypes::*;
import MemInit::*;
import Cache::*;
import SimMem::*;
import CacheTypes::*;
import MemInit::*;
import ClientServer::*;

// Data structure for Fetch to Decode stage
typedef struct {
    Addr pc;
    Addr predPc;
    Bool deEpoch;
    Bool exEpoch;
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
} ExRedirectPipe deriving (Bits, Eq);

typedef struct {
    Addr correctPpc;
} DcRedirectPipe deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Bool brTaken;
} BhtUpdatePipe deriving (Bits, Eq);

// redirect msg from Execute stage
module mkProc#(Fifo#(2, DDR3_Req) ddr3ReqFifo, Fifo#(2, DDR3_Resp) ddr3RespFifo) (Proc);
    Reg#(Addr)         pc <- mkReg(?);
    RFile              rf <- mkBypassRFile;
    Scoreboard#(6)     sb <- mkPipelineScoreboard;
    CsrFile          csrf <- mkCsrFile;
    Btb#(6)           btb <- mkBtb; // 64-entry BTB
    DirectionPred#(8) bht <- mkBHT; // 256-entry BHT
    Ras#(3)           ras <- mkRas; // 8-element RAS

    Vector#(2, Reg#(Bool)) fEpoch <- replicateM(mkReg(False));
    Ehr#(2, Bool) exEpoch <- mkEhr(False);
    Ehr#(2, Bool) deEpoch <- mkEhr(False);

    // FIFOs between stages
    FIFO#(Fetch2Decode)              f2d <- mkPipelineFIFO;
    FIFO#(Decode2RegRead)            d2r <- mkPipelineFIFO;
    FIFO#(RegRead2Exec)              r2e <- mkPipelineFIFO;
    FIFO#(Maybe#(Exec2WriteBack))    e2m <- mkPipelineFIFO;
    FIFO#(Maybe#(Exec2WriteBack))    m2w <- mkPipelineFIFO;

    FIFOF#(ExRedirectPipe)  exRedirectPipe <- mkBypassFIFOF;
    FIFOF#(Addr)            dcRedirectPipe <- mkBypassFIFOF;
    FIFOF#(BhtUpdatePipe)   bhtUpdatePipe  <- mkBypassFIFOF;

    Bool memReady = True;
    let                         wideMem     <- mkWideMemFromDDR3(ddr3ReqFifo,ddr3RespFifo);
    Vector#(2, WideMem)         splitMem    <- mkSplitWideMem(memReady && csrf.started, wideMem);

    Cache iMem <- mkTranslator( splitMem[1] );
    Cache dMem <- mkTranslator( splitMem[0] );

    rule fetchStage if (csrf.started);
        Bool dEp;
        Bool eEp;
        Addr ppc;
        Addr currpc;
        if (exRedirectPipe.notEmpty) begin
            $display("[fetch] execute redirect");
            dEp = fEpoch[0];
            eEp = !fEpoch[1];
            fEpoch[0] <= dEp;
            fEpoch[1] <= eEp;
            ppc = btb.predPc(exRedirectPipe.first.correctPpc);
            currpc = exRedirectPipe.first.correctPpc;

            btb.update(exRedirectPipe.first.currPc, exRedirectPipe.first.correctPpc);
        end else if (dcRedirectPipe.notEmpty) begin
            $display("[fetch] decode redirect");
            dEp = !fEpoch[0];
            eEp = fEpoch[1];
            fEpoch[0] <= dEp;
            fEpoch[1] <= eEp;
            ppc = btb.predPc(dcRedirectPipe.first);
            currpc = dcRedirectPipe.first;
        end else begin
            dEp = fEpoch[0];
            eEp = fEpoch[1];
            currpc = pc;
            ppc = btb.predPc(pc);
            fEpoch[0] <= dEp;
            fEpoch[1] <= eEp;
        end
        iMem.req(MemReq{op: Ld, addr: currpc, data: ?});
        if (exRedirectPipe.notEmpty) begin
            exRedirectPipe.deq;
        end
        if (dcRedirectPipe.notEmpty) begin
            dcRedirectPipe.deq;
        end

        $display("[fetch] pc -> %h", currpc);
        pc <= ppc;
        f2d.enq(Fetch2Decode{pc: currpc, predPc: ppc, deEpoch: dEp, exEpoch: eEp});
    endrule

    rule decodeStage;
        let x = f2d.first;
        $display("[decode] pc -> %h", x.pc);
        f2d.deq;
        let inst <- iMem.resp();
        if (exEpoch[1] == x.exEpoch && deEpoch[0] == x.deEpoch) begin
            $display("pc: %h inst: (%h) expanded: ", x.pc, inst, showInst(inst));
            let dInst = decode(inst);

            if (dInst.iType == Br) begin
                $display("[decode] decode a Branch Type");
                let brPred = bht.ppcDP(x.pc, x.predPc);
                if (brPred != x.predPc) begin
                    $display("[decode] found error misprediction, redirect");
                    deEpoch[0] <= !deEpoch[0];
                    dcRedirectPipe.enq(brPred);
                    x.predPc = brPred;
                end
            end else if (dInst.iType == J) begin
                $display("[decode] decode J Type, redirect");
                let brPred = x.pc + fromMaybe(?, dInst.imm);
                deEpoch[0] <= !deEpoch[0];
                dcRedirectPipe.enq(brPred);
                x.predPc = brPred;
                ras.push(x.pc+4);
            end else if (dInst.iType == Jr) begin
                $display("[decode] decode Jr Type, redirect");
                let brPred <- ras.pop();
                deEpoch[0] <= !deEpoch[0];
                dcRedirectPipe.enq(brPred);
                x.predPc = brPred;
            end

            d2r.enq(Decode2RegRead{pc: x.pc, predPc: x.predPc, epoch: x.exEpoch, dInst: dInst});
        end else begin
            $display("[decode] because misprediction, throw it");
        end

        if (bhtUpdatePipe.notEmpty) begin
            $display("[decode] Got B-Type, update Bht, deq updataPipe");
            bht.update(bhtUpdatePipe.first.pc, bhtUpdatePipe.first.brTaken);
            bhtUpdatePipe.deq;
        end

    endrule

    rule rfFetchStage;
        let x = d2r.first;
        let dInst = x.dInst;
        $display("[regFileFetch] pc -> %h", x.pc);
        if (exEpoch[1] == x.epoch) begin
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
        if (exEpoch[0] == x.epoch) begin
            let eInst = exec(x.dInst, x.rVal1, x.rVal2, x.pc, x.predPc, x.csrVal);

            // check unsupported instruction at commit time. Exiting
            if(eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", x.pc);
                $finish;
            end

            if (eInst.mispredict) begin
                $display("[execute] occure misprediction: pred: %h, actual: %h", x.predPc, eInst.addr);
                exEpoch[0] <= !exEpoch[0];
                exRedirectPipe.enq(ExRedirectPipe{currPc: x.pc, correctPpc: eInst.addr});
                // pc[0] <= eInst.addr;
                // btb.update(x.pc, eInst.addr);
            end

            if(eInst.iType == Br) begin
                $display("[execute] Got B-Type, update Bht, enq updataPipe");
                bhtUpdatePipe.enq(BhtUpdatePipe{pc: x.pc, brTaken: eInst.brTaken});
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

    // (* fire_when_enabled *)
    // (* no_implicit_conditions *)
    // rule cononicalizeRedirect if (csrf.started);

    // endrule

    method ActionValue#(CpuToHostData) cpuToHost if(csrf.started);
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
    $display("Start cpu");
        csrf.start(0); // only 1 core, id = 0
        pc <= startpc;
    endmethod
endmodule

