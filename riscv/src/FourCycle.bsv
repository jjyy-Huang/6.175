// FourCycle.bsv
//
// This is a four cycle implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import MemInit::*;
import RFile::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import DelayedMemory::*;
typedef enum {
    Fetch,
    Decode,
    Execute,
    WriteBack
} Stage deriving(Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr)    pc <- mkRegU;
    RFile         rf <- mkRFile;
    DelayedMemory mem <- mkDelayedMemory;
    let dummyInit     <- mkDummyMemInit;
    CsrFile       csrf <- mkCsrFile;
    Reg#(Stage) currStage <- mkReg(Fetch);

    Bool memReady = mem.init.done && dummyInit.done;

    Reg#(Stage) state <- mkReg(Fetch);
    Reg#(DecodedInst) dInst <- mkRegU;
    Reg#(ExecInst) eInst <- mkRegU;
    Reg#(Data) rVal1 <- mkRegU;
    Reg#(Data) rVal2 <- mkRegU;
    Reg#(Data) csrVal <- mkRegU;

    // TODO: complete implementation of this processor

    rule fcStage if (csrf.started && currStage == Fetch);
        mem.req(MemReq{op: Ld, addr: pc, data: ?});
        currStage <= Decode;
        $display("----------fetch stage----------");

    endrule

    rule dcStage if (csrf.started && currStage == Decode);
        let inst <- mem.resp();
        let tmpInst = decode(inst);
        dInst <= tmpInst;
        currStage <= Execute;
        $display("----------decode stage----------");
        $display("pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
        rVal1 <= rf.rd1(fromMaybe(?, tmpInst.src1));
        rVal2 <= rf.rd2(fromMaybe(?, tmpInst.src2));

        // read CSR values (for CSRR inst)
        csrVal <= csrf.rd(fromMaybe(?, tmpInst.csr));

    endrule

    rule exStage if (csrf.started && currStage == Execute);
        $display("----------execute stage----------");
        let tmpInst = exec(dInst, rVal1, rVal2, pc, ?, csrVal);
        eInst <= tmpInst;

        // memory
        if(tmpInst.iType == Ld) begin
            mem.req(MemReq{op: Ld, addr: tmpInst.addr, data: ?});
        end else if(tmpInst.iType == St) begin
            mem.req(MemReq{op: St, addr: tmpInst.addr, data: tmpInst.data});
        end

        // check unsupported instruction at commit time. Exiting
        if(tmpInst.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
            $finish;
        end

        currStage <= WriteBack;
    endrule

    rule wbStage if (csrf.started && currStage == WriteBack);
        $display("----------write back stage----------");
        Data wbData;
        if (eInst.iType == Ld) begin
            wbData <- mem.resp();
        end else begin
            wbData = eInst.data;
        end

        // write back to reg file
        if(isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), wbData);
        end

        // update the pc depending on whether the branch is taken or not
        pc <= eInst.brTaken ? eInst.addr : pc + 4;

        // CSR write for sending data to host & stats
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, wbData);

        currStage <= Fetch;
    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
        pc <= startpc;
    endmethod

    interface iMemInit = dummyInit;
    interface dMemInit = mem.init;
endmodule

