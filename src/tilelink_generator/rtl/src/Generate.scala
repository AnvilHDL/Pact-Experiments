import chisel3.util.experimental.BitSet
import org.chipsalliance.tilelink.bundle.TLLinkParameter
import org.chipsalliance.tilelink.xbar._
object Generate {
  def main(args: Array[String]): Unit = {
    // Every transfer (at most 2 bytes) fits one 16-bit beat, so there are no bursts.
    val link = TLLinkParameter(addressWidth = 16, sourceWidth = 2, sinkWidth = 2,
      dataWidth = 16, sizeWidth = 1, hasBCEChannels = true)
    val masters = (0 until 2).map(i => TLCrossBarMasterLinkParameter(
      link, BitSet.fromString("b??"), BitSet.empty, TLIdRange(0, 1)))
    val slaves = (0 until 2).map(i => TLCrossBarSlaveLinkParameter(
      link, BitSet.fromString("b??"), BitSet.empty, TLIdRange(0, 1),
      BitSet.fromString("b???????????????" + i)))
    val config = TLCrossBarParameter(TLArbiterPolicy.RoundRobin, masters, slaves)
    (new chisel3.stage.ChiselStage).emitVerilog(new TLCrossBar(config),
      Array("--target-dir", args(0)))
  }
}
