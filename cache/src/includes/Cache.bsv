
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