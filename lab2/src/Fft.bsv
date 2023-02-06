import Vector::*;
import Complex::*;
import FftCommon::*;
import Fifo::*;
import FIFOF::*;
import Cntrs :: *;

interface Fft;
    method Action enq(Vector#(FftPoints, ComplexData) in);
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
endinterface

(* synthesize *)
module mkFftCombinational(Fft);
  FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
  FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
  Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

  function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
    Vector#(FftPoints, ComplexData) stage_temp, stage_out;
    for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
      FftIdx idx = i * 4;
      Vector#(4, ComplexData) x;
      Vector#(4, ComplexData) twid;
      for (FftIdx j = 0; j < 4; j = j + 1 ) begin
        x[j] = stage_in[idx+j];
        twid[j] = getTwiddle(stage, idx+j);
      end
      let y = bfly[stage][i].bfly4(twid, x);

      for(FftIdx j = 0; j < 4; j = j + 1 ) begin
        stage_temp[idx+j] = y[j];
      end
    end

    stage_out = permute(stage_temp);

    return stage_out;
  endfunction

  rule doFft if(inFifo.notEmpty && outFifo.notFull);
    inFifo.deq;
    Vector#(4, Vector#(FftPoints, ComplexData)) stage_data;
    stage_data[0] = inFifo.first;

    for (StageIdx stage = 0; stage < 3; stage = stage + 1) begin
      stage_data[stage+1] = stage_f(stage, stage_data[stage]);
    end
    outFifo.enq(stage_data[3]);
  endrule

  method Action enq(Vector#(FftPoints, ComplexData) in);
    inFifo.enq(in);
  endmethod

  method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
    outFifo.deq;
    return outFifo.first;
  endmethod
endmodule

(* synthesize *)
module mkFftInelasticPipeline(Fft);
  FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
  FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
  Vector#(3, Vector#(16, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

  Reg#(Maybe #( Vector#(FftPoints, ComplexData))) stageReg <- mkRegU;
  Reg#(Bool) inSel <- mkRegU;


  function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
    Vector#(FftPoints, ComplexData) stage_temp, stage_out;
    for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
      FftIdx idx = i * 4;
      Vector#(4, ComplexData) x;
      Vector#(4, ComplexData) twid;
      for (FftIdx j = 0; j < 4; j = j + 1 ) begin
        x[j] = stage_in[idx+j];
        twid[j] = getTwiddle(stage, idx+j);
      end
      let y = bfly[stage][i].bfly4(twid, x);

      for(FftIdx j = 0; j < 4; j = j + 1 ) begin
        stage_temp[idx+j] = y[j];
      end
    end

    stage_out = permute(stage_temp);

    return stage_out;
  endfunction

  rule getFftData if(inFifo.notEmpty && !isValid(stageReg));
      stageReg <= tagged Valid (stage_f(0, inFifo.first));
      inSel <= True;
      inFifo.deq;
  endrule

  rule doFft if (isValid(stageReg));
    if (inSel) begin
      stageReg <= tagged Valid stage_f(1, fromMaybe(?, stageReg));
      inSel <= False;
    end else begin
      outFifo.enq(stage_f(2, fromMaybe(?, stageReg)));
      stageReg <= tagged Invalid;
      inSel <= True;
    end
  endrule

  method Action enq(Vector#(FftPoints, ComplexData) in);
    inFifo.enq(in);
  endmethod

  method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
    outFifo.deq;
    return outFifo.first;
  endmethod
endmodule

(* synthesize *)
module mkFftElasticPipeline(Fft);
  Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo <- mkFifo;
  Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkFifo;

  Vector#(2, Fifo#(3, Vector#(FftPoints, ComplexData))) interFifo <- replicateM(mkFifo);

  Vector#(3, Vector#(16, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));


  function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
    Vector#(FftPoints, ComplexData) stage_temp, stage_out;
    for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
      FftIdx idx = i * 4;
      Vector#(4, ComplexData) x;
      Vector#(4, ComplexData) twid;
      for (FftIdx j = 0; j < 4; j = j + 1 ) begin
        x[j] = stage_in[idx+j];
        twid[j] = getTwiddle(stage, idx+j);
      end
      let y = bfly[stage][i].bfly4(twid, x);

      for(FftIdx j = 0; j < 4; j = j + 1 ) begin
        stage_temp[idx+j] = y[j];
      end
    end

    stage_out = permute(stage_temp);

    return stage_out;
  endfunction

    //TODO: Implement the rest of this module
    // You should use more than one rule

  rule stage0;
    interFifo[0].enq(stage_f(0, inFifo.first));
    inFifo.deq;
  endrule

  rule stage1;
    interFifo[1].enq(stage_f(1, interFifo[0].first));
    interFifo[0].deq;
  endrule

  rule stage2;
    outFifo.enq(stage_f(2, interFifo[1].first));
    interFifo[1].deq;
  endrule

  method Action enq(Vector#(FftPoints, ComplexData) in);
    inFifo.enq(in);
  endmethod

  method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
    outFifo.deq;
    return outFifo.first;
  endmethod
endmodule

