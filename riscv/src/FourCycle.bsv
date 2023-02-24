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
import FPGAMemory::*;
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
    FPGAMemory mem <- mkFPGAMemory;
    let dummyInit     <- mkDummyMemInit;
    CsrFile       csrf <- mkCsrFile;

    Bool memReady = mem.init.done && dummyInit.done;

    Reg#(Stage) state <- mkReg(Fetch);
    Reg#(DecodedInst) dInst <- mkRegU;
    Reg#(ExecInst) eInst <- mkRegU;

    // TODO: complete implementation of this processor

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

