import Ehr::*;
import Vector::*;

//////////////////
// Fifo interface

interface Fifo#(numeric type n, type t);
  method Bool notFull;
  method Action enq(t x);
  method Bool notEmpty;
  method Action deq;
  method t first;
  method Action clear;
endinterface

/////////////////
// Conflict FIFO

module mkMyConflictFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
  // n is size of fifo
  // t is data type of fifo
  Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
  Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
  Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
  Reg#(Bool)              empty    <- mkReg(True);
  Reg#(Bool)              full     <- mkReg(False);

  // useful value
  Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

  // TODO: Implement all the methods for this module

  method Bool notFull;
    return !full;
  endmethod

  method Bool notEmpty;
    return !empty;
  endmethod

  method t first() if (!empty);
    return data[deqP];
  endmethod

  method Action clear;
    enqP <= 0;
    deqP <= 0;
    empty <= True;
    full <= False;
  endmethod

  method Action enq(t x) if (!full);
    data[enqP] <= x;
    let tmpEnqP = enqP + 1;
    if (tmpEnqP > max_index)
      tmpEnqP = 0;
    if (tmpEnqP == deqP)
      full <= True;

    enqP <= tmpEnqP;
    empty <= False;
  endmethod

  method Action deq if (!empty);
    let tmpDeqP = deqP + 1;
    if (tmpDeqP > max_index)
      tmpDeqP = 0;
    if (tmpDeqP == enqP)
      empty <= True;

    deqP <= tmpDeqP;
    full <= False;
  endmethod
endmodule

/////////////////
// Pipeline FIFO

// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear
module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
  // n is size of fifo
  // t is data type of fifo
  Vector#(n, Reg#(t))      data     <- replicateM(mkRegU());
  Ehr#(3, Bit#(TLog#(n)))  enqP     <- mkEhr(0);
  Ehr#(3, Bit#(TLog#(n)))  deqP     <- mkEhr(0);
  Ehr#(3, Bool)            empty    <- mkEhr(True);
  Ehr#(3, Bool)            full     <- mkEhr(False);
  Bit#(TLog#(n))           max_index = fromInteger(valueOf(n)-1);

  method Bool notFull;
    return !full[1];
  endmethod

  method Bool notEmpty;
    return !empty[0];
  endmethod

  method Action clear;
    enqP[2]  <= 0;
    deqP[2]  <= 0;
    empty[2] <= True;
    full[2]  <= False;
  endmethod

  method t first if (!empty[0]);
    return data[deqP[0]];
  endmethod

  method Action enq(t x) if(!full[1]);
    data[enqP[1]] <= x;
    let tmpEnqP = enqP[1] + 1;
    if (tmpEnqP > max_index)
      tmpEnqP = 0;
    if (tmpEnqP == deqP[1])
      full[1] <= True;

    enqP[1] <= tmpEnqP;
    empty[1] <= False;
  endmethod

  method Action deq if (!empty[0]);
    let tmpDeqP = deqP[0] + 1;
    if (tmpDeqP > max_index)
      tmpDeqP = 0;
    if (tmpDeqP == enqP[0])
      empty[0] <= True;

    deqP[0] <= tmpDeqP;
    full[0] <= False;
  endmethod

endmodule

/////////////////////////////
// Bypass FIFO without clear

// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
  // n is size of fifo
  // t is data type of fifo
  Vector#(n, Ehr#(2, t))      data     <- replicateM(mkEhrU());
  Ehr#(3, Bit#(TLog#(n)))  enqP     <- mkEhr(0);
  Ehr#(3, Bit#(TLog#(n)))  deqP     <- mkEhr(0);
  Ehr#(3, Bool)            empty    <- mkEhr(True);
  Ehr#(3, Bool)            full     <- mkEhr(False);
  Bit#(TLog#(n))           max_index = fromInteger(valueOf(n)-1);

  method Bool notFull;
    return !full[0];
  endmethod

  method Bool notEmpty;
    return !empty[1];
  endmethod

  method Action clear;
    enqP[2]  <= 0;
    deqP[2]  <= 0;
    empty[2] <= True;
    full[2]  <= False;
  endmethod

  method t first if (!empty[1]);
    return data[deqP[1]][1];
  endmethod

  method Action enq(t x) if(!full[0]);
    data[enqP[0]][0] <= x;
    let tmpEnqP = enqP[0] + 1;
    if (tmpEnqP > max_index)
      tmpEnqP = 0;
    if (tmpEnqP == deqP[0])
      full[0] <= True;

    enqP[0] <= tmpEnqP;
    empty[0] <= False;
  endmethod

  method Action deq if (!empty[1]);
    let tmpDeqP = deqP[1] + 1;
    if (tmpDeqP > max_index)
      tmpDeqP = 0;
    if (tmpDeqP == enqP[1])
      empty[1] <= True;

    deqP[1] <= tmpDeqP;
    full[1] <= False;
  endmethod
endmodule

//////////////////////
// Conflict free fifo

// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear
module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
  // n is size of fifo
  // t is data type of fifo
  Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
  Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
  Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
  Reg#(Bool)              empty    <- mkReg(True);
  Reg#(Bool)              full     <- mkReg(False);
  // useful value
  Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

  Ehr#(2, Maybe#(t))      enqReq   <- mkEhr(tagged Invalid);
  Ehr#(2, Bool)           deqReq   <- mkEhr(False);
  Ehr#(2, Bool)           clearReq <- mkEhr(False);
  // TODO: Implement all the methods for this module


  (* no_implicit_conditions *)
  (* fire_when_enabled *)
  rule canonicalize;
    if (clearReq[1]) begin
      enqP <= 0;
      deqP <= 0;
      empty <= False;
      full <= False;
    end else begin
      let tmpEnqP = enqP;
      let tmpDeqP = deqP;

      // deq request when not empty
      if (deqReq[1] && !empty) begin
        tmpDeqP = deqP + 1;
        if (tmpDeqP > max_index)
          tmpDeqP = 0;
      end
      // enq request when not full
      if (isValid(enqReq[1]) && !full) begin
        data[enqP] <= fromMaybe(?, enqReq[1]);
        tmpEnqP = enqP + 1;
        if (tmpEnqP > max_index)
          tmpEnqP = 0;
      end
      // focue on empty and full signal conflict
      if (isValid(enqReq[1]) && !full && deqReq[1] && !empty) begin
        empty <= empty;
        full <= full;
      end else if (deqReq[1] && !empty) begin
        if (tmpDeqP == tmpEnqP)
          empty <= True;
        full <= False;
      end else if (isValid(enqReq[1]) && !full) begin
        if (tmpDeqP == tmpEnqP)
          full <= True;
        empty <= False;
      end

      enqP <= tmpEnqP;
      deqP <= tmpDeqP;
    end
    enqReq[1] <= tagged Invalid;
    deqReq[1] <= False;
    clearReq[1] <= False;
  endrule

  method Bool notFull;
    return !full;
  endmethod

  method Bool notEmpty;
    return !empty;
  endmethod

  method t first() if (!empty);
    return data[deqP];
  endmethod

  method Action clear;
    clearReq[0] <= True;
  endmethod

  method Action enq(t x) if (!full);
    enqReq[0] <= tagged Valid x;
  endmethod

  method Action deq if (!empty);
    deqReq[0] <= True;
  endmethod

endmodule

