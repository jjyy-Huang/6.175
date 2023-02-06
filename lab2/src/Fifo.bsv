import Ehr::*;
import Vector::*;
import FIFO::*;

interface Fifo#(numeric type n, type t);
  method Action enq(t x);
  method Action deq;
  method t first;
  method Bool notEmpty;
endinterface


module mkFifo(Fifo#(3,t)) provisos (Bits#(t,tSz));
  // define your own 3-elements fifo here.
  Vector#(3, Reg#(Maybe#(t))) data <- replicateM(mkReg(tagged Invalid));

  // Enq if there's at least one spot open... so, dc is invalid.
  method Action enq(t x) if (!isValid (data[2]));
    if (!isValid(data[0])) begin
      data[0] <= tagged Valid (x);
    end else if (!isValid(data[1])) begin
      data[1] <= tagged Valid (x);
    end else begin
      data[2] <= tagged Valid (x);
    end
  endmethod

  //Deq if there's a valid data at da
  method Action deq() if (isValid(data[0]));
    if (isValid(data[2])) begin
      data[0] <= data[1];
      data[1] <= data[2];
      data[2] <= tagged Invalid;
    end else if (isValid(data[1])) begin
      data[0] <= data[1];
      data[1] <= tagged Invalid;
    end
    else begin data[0] <= tagged Invalid; end
  endmethod

  //First if there's a valid data at da
  method t first() if (isValid(data[0]));
    return fromMaybe(?, data[0]);
  endmethod

  //Check if fifo's empty
  method Bool notEmpty();
    return isValid(data[0]);
  endmethod

endmodule


// Two elements conflict-free fifo given as black box
module mkCFFifo( Fifo#(2, t) ) provisos (Bits#(t, tSz));
    Ehr#(2, t) da <- mkEhr(?);
    Ehr#(2, Bool) va <- mkEhr(False);
    Ehr#(2, t) db <- mkEhr(?);
    Ehr#(2, Bool) vb <- mkEhr(False);

    rule canonicalize;
        if( vb[1] && !va[1] ) begin
            da[1] <= db[1];
            va[1] <= True;
            vb[1] <= False;
        end
    endrule

    method Action enq(t x) if(!vb[0]);
        db[0] <= x;
        vb[0] <= True;
    endmethod

    method Action deq() if(va[0]);
        va[0] <= False;
    endmethod

    method t first if (va[0]);
        return da[0];
    endmethod

    method Bool notEmpty();
        return va[0];
    endmethod
endmodule

module mkCF3Fifo(Fifo#(3,t)) provisos (Bits#(t, tSz));
    FIFO#(t) bsfif <-  mkSizedFIFO(3);
    method Action enq( t x);
        bsfif.enq(x);
    endmethod

    method Action deq();
        bsfif.deq();
    endmethod

    method t first();
        return bsfif.first();
    endmethod

    method Bool notEmpty();
        return True;
    endmethod

endmodule
