function Bit#(1) and1(Bit#(1) a, Bit#(1) b);
    return a & b;
endfunction

function Bit#(1) or1(Bit#(1) a, Bit#(1) b);
    return a | b;
endfunction

function Bit#(1) xor1(Bit#(1) a, Bit#(1) b);
    return a ^ b;
endfunction

function Bit#(1) not1(Bit#(1) a);
    return ~a;
endfunction

function Bit#(1) multiplexer1(Bit#(1) selIn, Bit#(1) aIn, Bit#(1) bIn);
  // let selected = (selIn == 0) ? aIn: bIn;
  let selectedOut = or1(and1(not1(selIn), aIn), and1(selIn, bIn));
  return selectedOut;
endfunction

function Bit#(5) multiplexer5(Bit#(1) selIn, Bit#(5) aIn, Bit#(5) bIn);
  Bit#(5) selectedOut;
  for (Integer idx = 0; idx < 5; idx = idx+1) begin
    selectedOut[idx] = multiplexer1(selIn, aIn[idx], bIn[idx]);
  end
  return selectedOut;
  // return multiplexer_n(selIn, aIn, bIn);
endfunction

typedef 5 N;
function Bit#(N) multiplexerN(Bit#(1) selIn, Bit#(N) aIn, Bit#(N) bIn);
  let widthValue = valueOf(N);
  Bit#(N) selectedOut;
  for (Integer idx = 0; idx < widthValue; idx = idx+1) begin
    selectedOut[idx] = multiplexer1(selIn, aIn[idx], bIn[idx]);
  end
  return selectedOut;
endfunction

//typedef 32 N; // Not needed
function Bit#(n) multiplexer_n(Bit#(1) selIn, Bit#(n) aIn, Bit#(n) bIn);
  let widthValue = valueOf(n);
  Bit#(n) selectedOut;
  for (Integer idx = 0; idx < widthValue; idx = idx+1) begin
    selectedOut[idx] = multiplexer1(selIn, aIn[idx], bIn[idx]);
  end
  return selectedOut;
endfunction
