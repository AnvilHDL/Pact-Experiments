import mill._, scalalib._
object rtl extends ScalaModule {
  def scalaVersion = "2.13.10"
  def ivyDeps = Agg(ivy"edu.berkeley.cs::chisel3:3.6.1")
  def scalacPluginIvyDeps = Agg(ivy"edu.berkeley.cs:::chisel3-plugin:3.6.1")
  override def sources = T.sources {
    Seq(PathRef(millSourcePath / "tilelink_src"), PathRef(millSourcePath / "src"))
  }
}
