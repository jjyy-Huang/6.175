import Multiplexer::*;

// Full adder functions

function Bit#(1) fa_sum(Bit#(1) a, Bit#(1) b, Bit#(1) c_in);
    return xor1(xor1(a, b), c_in);
endfunction

function Bit#(1) fa_carry(Bit#(1) a, Bit#(1) b, Bit#(1) c_in);
    return or1(and1(a, b), and1(xor1(a, b), c_in));
endfunction

// 4 Bit full adder

function Bit#(5) add4(Bit#(4) a, Bit#(4) b, Bit#(1) c_in);
    return ripplerAdderN(a, b, c_in);
endfunction

// Adder interface

interface Adder8;
    method ActionValue#(Bit#(9)) sum(Bit#(8) a, Bit#(8) b, Bit#(1) c_in);
endinterface

// Adder modules

// RC = Ripple Carry
module mkRCAdder(Adder8);
    method ActionValue#(Bit#(9)) sum(Bit#(8) a, Bit#(8) b, Bit#(1) c_in);
        Bit#(5) lower_result = add4(a[3:0], b[3:0], c_in);
        Bit#(5) upper_result = add4(a[7:4], b[7:4], lower_result[4]);
        return { upper_result , lower_result[3:0] };
    endmethod
endmodule

// CS = Carry Select
module mkCSAdder(Adder8);
  method ActionValue#(Bit#(9)) sum(Bit#(8) aIn, Bit#(8) bIn, Bit#(1) cIn);
    let lowerResult = add4(aIn[3: 0], bIn[3: 0], cIn);
    let carrySelect = lowerResult[4];
    let upperResultIfIncr = add4(aIn[7: 4], bIn[7: 4], 1);
    let upperResultIfNotIncr = add4(aIn[7: 4], bIn[7: 4], 0);
    let upperResult = multiplexer_n(carrySelect, upperResultIfNotIncr, upperResultIfIncr);
    return {upperResult, lowerResult[3: 0]};
  endmethod
endmodule

function Bit#(TAdd#(width, 1)) ripplerAdderN(Bit#(width) aIn, Bit#(width) bIn, Bit#(1) cIn);
  Bit#(width) sOut;
  Bit#(TAdd#(width, 1)) carry = 0; // can not init part of it
  let widthValue = valueOf(width);
  carry[0] = cIn;
  for(Integer idx = 0; idx < widthValue; idx = idx + 1) begin
    sOut[idx] = fa_sum(aIn[idx], bIn[idx], carry[idx]);
    carry[idx + 1] = fa_carry(aIn[idx], bIn[idx], carry[idx]);
  end
  return {carry[widthValue], sOut};
endfunction