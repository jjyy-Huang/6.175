import Vector::*;
import Multiplexer::*;

function Bit#(width) shifterRigthPow(Bit#(width) dataIn, Integer shiftLen);
  Bit#(width) shifted = 0;
  let widthValue = valueOf(width);
  for(Integer idx = 0; idx < widthValue - shiftLen; idx = idx + 1) begin
    shifted[idx] = dataIn[idx + shiftLen];
  end
  // let upper = dataIn[valueOf(width)/2-1: 0];
  // let lower = dataIn[valueOf(width) - 1: valueOf(width)/2];
  // let result = {upper, lower};
  return shifted;
endfunction

function Bit#(width) barrelShifterRight(Bit#(width) dataIn, Bit#(TLog#(width)) shiftPos);
  let dataWidthValue = valueOf(width);
  let shiftWidthValue = valueOf(TLog#(width));
  Bit#(width) shifted;
  shifted = dataIn;

  for(Integer idx = 0; idx < shiftWidthValue; idx = idx + 1) begin
    Integer shiftLen = 2**idx;
    shifted = multiplexer_n(shiftPos[idx], shifted, shifterRigthPow(shifted, shiftLen));
  end
  return shifted;
endfunction