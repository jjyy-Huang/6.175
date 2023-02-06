// Reference functions that use Bluespec's '*' operator
function Bit#(TAdd#(n,n)) multiply_unsigned( Bit#(n) a, Bit#(n) b );
  UInt#(n) a_uint = unpack(a);
  UInt#(n) b_uint = unpack(b);
  UInt#(TAdd#(n,n)) product_uint = zeroExtend(a_uint) * zeroExtend(b_uint);
  return pack( product_uint );
endfunction

function Bit#(TAdd#(n,n)) multiply_signed( Bit#(n) a, Bit#(n) b );
  Int#(n) a_int = unpack(a);
  Int#(n) b_int = unpack(b);
  Int#(TAdd#(n,n)) product_int = signExtend(a_int) * signExtend(b_int);
  return pack( product_int );
endfunction

  //       1 0 1 1
  //     x 1 1 0 1
  // ---------------
  //       1 0 1 1
  //     0 0 0 0
  //   1 0 1 1
  // 1 0 1 1

// Multiplication by repeated addition
function Bit#(TAdd#(n,n)) multiply_by_adding( Bit#(n) a, Bit#(n) b );
  // TODO: Implement this function in Exercise 2
  Bit#(n) prod = 0;
  Bit#(n) tp = 0;
  for(Integer idx = 0; idx < valueOf(n); idx = idx + 1) begin
    Bit#(n) tmp = (a[idx] == 1) ? b : 0;
    Bit#(TAdd#(n, 1)) sum = zeroExtend(tmp) + zeroExtend(tp);
    tp = truncateLSB(sum);
    prod[idx] = lsb(sum);
  end
  return {tp, prod};
endfunction

// Multiplier Interface
interface Multiplier#( numeric type n );
  method Bool start_ready();
  method Action start( Bit#(n) a, Bit#(n) b );
  method Bool result_ready();
  method ActionValue#(Bit#(TAdd#(n,n))) result();
endinterface

// Folded multiplier by repeated addition
module mkFoldedMultiplier( Multiplier#(n) );
  // You can use these registers or create your own if you want
  Reg#(Bit#(n)) a <- mkRegU();
  Reg#(Bit#(n)) b <- mkRegU();
  Reg#(Bit#(n)) prod <- mkRegU();
  Reg#(Bit#(n)) tp <- mkRegU();
  Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

  let startRdy = i == fromInteger(valueOf(n) + 1);
  let resultRdy = i == fromInteger(valueOf(n));

  rule mulStep( i < fromInteger(valueOf(n)) );
    // TODO: Implement this in Exercise 4
    Bit#(n) tmp = (a[i] == 1) ? b : 0;
    Bit#(TAdd#(n, 1)) sum = zeroExtend(tmp) + zeroExtend(tp);
    tp <= truncateLSB(sum);
    prod[i] <= lsb(sum);
    i <= i + 1;
  endrule

  method Bool start_ready();
    // TODO: Implement this in Exercise 4
    return startRdy;
  endmethod

  method Action start( Bit#(n) aIn, Bit#(n) bIn ) if(startRdy);
    // TODO: Implement this in Exercise 4
    a <= aIn;
    b <= bIn;
    tp <= 0;
    prod <= 0;
    i <= 0;
  endmethod

  method Bool result_ready();
    // TODO: Implement this in Exercise 4
    return resultRdy;
  endmethod

  method ActionValue#(Bit#(TAdd#(n,n))) result() if(resultRdy);
    // TODO: Implement this in Exercise 4
    i <= i + 1;
    return {tp, prod};
  endmethod
endmodule


function Bit#(n) shiftArth(Bit#(n) data, Integer nBit, Bool isRight);
  Int#(n) dataInt = unpack(data);
  return isRight ? pack(dataInt >> nBit) : pack(dataInt << nBit);
endfunction

// Booth Multiplier
module mkBoothMultiplier( Multiplier#(n) );
  Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_neg <- mkRegU;
  Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_pos <- mkRegU;
  Reg#(Bit#(TAdd#(TAdd#(n,n),1))) p <- mkRegU;
  Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

  let startRdy = i == fromInteger(valueOf(n) + 1);
  let resultRdy = i == fromInteger(valueOf(n));

  rule mul_step( i < fromInteger(valueOf(n)) );
    // TODO: Implement this in Exercise 6
    let tmpp = p;
    let pr = p[1:0];
    if (pr == 2'b01) begin
      tmpp = p + m_pos;
    end else if (pr == 2'b10) begin
      tmpp = p + m_neg;
    end
    p <= shiftArth(tmpp, 1, True);
    i <= i + 1;
  endrule

  method Bool start_ready();
    // TODO: Implement this in Exercise 6
    return startRdy;
  endmethod

  method Action start( Bit#(n) m, Bit#(n) r ) if(startRdy);
    // TODO: Implement this in Exercise 6
    m_pos <= {m, 0};
    m_neg <= {(-m), 0};
    p <= {0, r, 1'b0};
    i <= 0;

  endmethod

  method Bool result_ready();
    // TODO: Implement this in Exercise 6
    return resultRdy;
  endmethod

  method ActionValue#(Bit#(TAdd#(n,n))) result() if(resultRdy);
    // TODO: Implement this in Exercise 6
    i <= i + 1;
    return p[2*valueOf(n): 1];
  endmethod
endmodule


// 00 | 0 |  00  |  00
// 00 | 1 |  0+  |  0+
// 01 | 0 |  +-  |  0+
// 01 | 1 |  +0  |  +0
// 10 | 0 |  -0  |  -0
// 10 | 1 |  -+  |  0-
// 11 | 0 |  0-  |  0-
// 11 | 1 |  00  |  00

// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4( Multiplier#(n) );
  Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_neg <- mkRegU;
  Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_pos <- mkRegU;
  Reg#(Bit#(TAdd#(TAdd#(n,n),2))) p <- mkRegU;
  Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)/2+1) );

  let startRdy = i == fromInteger(valueOf(n)/2 + 1);
  let resultRdy = i == fromInteger(valueOf(n)/2);

  rule mul_step( i<fromInteger(valueOf(n)/2) );
    // TODO: Implement this in Exercise 8
    let tmpp = p;
    let pr = p[2:0];
    if      (pr == 3'b001) tmpp = p + m_pos;
    else if (pr == 3'b010) tmpp = p + m_pos;
    else if (pr == 3'b011) tmpp = p + shiftArth(m_pos, 1, False);
    else if (pr == 3'b100) tmpp = p + shiftArth(m_neg, 1, False);
    else if (pr == 3'b101) tmpp = p + m_neg;
    else if (pr == 3'b110) tmpp = p + m_neg;
    p <= shiftArth(tmpp, 2, True);
    i <= i + 1;
  endrule

  method Bool start_ready();
    // TODO: Implement this in Exercise 6
    return startRdy;
  endmethod

  method Action start( Bit#(n) m, Bit#(n) r );
    // TODO: Implement this in Exercise 8
    m_pos <= {msb(m), m, 0};
    m_neg <= {msb(-m), (-m), 0};
    p <= {0, r, 1'b0};
    i <= 0;
  endmethod

  method Bool result_ready();
    // TODO: Implement this in Exercise 6
    return resultRdy;
  endmethod

  method ActionValue#(Bit#(TAdd#(n,n))) result() if(resultRdy);
    // TODO: Implement this in Exercise 6
    i <= i + 1;
    return p[2*valueOf(n): 1];
  endmethod
endmodule

