
import CacheTypes::*;
import MemUtil::*;
import Fifo::*;
import Vector::*;
import Types::*;
import MemTypes::*;

module mkTranslator(WideMem mem, Cache ifc);

    function CacheWordSelect getOffset(Addr addr) = truncate(addr >> 2);
    Fifo#(2,MemReq) pendLdReq <- mkCFFifo;

    method Action req(MemReq r);
        if(r.op==Ld) begin
            pendLdReq.enq(r);
        end
        mem.req(toWideMemReq(r));
    endmethod

    method ActionValue#(MemResp) resp;
        let request = pendLdReq.first;
        pendLdReq.deq;

        let cacheLine <-mem.resp;
        let offset = getOffset(request.addr);
        return cacheLine[offset];
    endmethod
endmodule

typedef enum {
    Ready,
    StartMiss,
    SendFillReq,
    WaitFillResp
} ReqStatus deriving (Bits, Eq);

module mkBlockingCache#(WideMem mem)(Cache);
    Vector#(CacheRows, Reg#(CacheLine))         dataArr  <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(Maybe#(CacheTag)))  tagArr   <- replicateM(mkReg(Invalid));
    Vector#(CacheRows, Reg#(Bool))              dirtyArr <- replicateM(mkReg(False));

    Reg#(ReqStatus) state <- mkReg(Ready);
    Fifo#(1, MemResp) hitQ <- mkPipelineFifo;
    Reg#(MemReq)   missReq <- mkRegU;

    rule startMiss if (state == StartMiss);
        let idx      = getIndex(missReq.addr);
        let cacheTag = tagArr[idx];
        let dirty    = dirtyArr[idx];
        if (isValid(cacheTag) && dirty) begin
            let addr = {fromMaybe(?, cacheTag), idx, 4'b0, 2'b0};
            let data = dataArr[idx];
            mem.req(WideMemReq{
                write_en: '1,
                addr:     addr,
                data:     data
            });
        end
        state <= SendFillReq;
    endrule

    rule sendFillReq if (state == SendFillReq);
        let wideMemReq = toWideMemReq(missReq);
        wideMemReq.write_en = 0; // just load from ddr
        mem.req(wideMemReq);
        state <= WaitFillResp;
    endrule

    rule waitFillResp if (state == WaitFillResp);
        let idx      = getIndex(missReq.addr);
        let offset   = getWordSelect(missReq.addr);
        let reqTag   = getTag(missReq.addr);
        let memRespData <- mem.resp;
        tagArr[idx]  <= tagged Valid reqTag;
        if (missReq.op == Ld) begin
            dirtyArr[idx] <= False;
            dataArr[idx] <= memRespData;
            hitQ.enq(memRespData[offset]);
        end else begin
            memRespData[offset] = missReq.data;
            dirtyArr[idx]       <= True;
            dataArr[idx]        <= memRespData;
        end
        state <= Ready;
    endrule

    method Action req(MemReq r) if (state == Ready);
        let idx      = getIndex(r.addr);
        let offset   = getWordSelect(r.addr);
        let reqTag   = getTag(r.addr);

        let cacheTag = tagArr[idx];
        let hit      = isValid(cacheTag) ? fromMaybe(?, cacheTag) == reqTag : False;

        if (hit) begin
            let line = dataArr[idx];
            if (r.op == Ld) begin
                hitQ.enq(line[offset]);
            end else begin
                line[offset] = r.data;
                dataArr[idx] <= line;
                dirtyArr[idx] <= True;
            end
        end else begin
            missReq <= r;
            state <= StartMiss;
        end

    endmethod
    method ActionValue#(MemResp) resp;
        hitQ.deq;
        return hitQ.first;
    endmethod
endmodule