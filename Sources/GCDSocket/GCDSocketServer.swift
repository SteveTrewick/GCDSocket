import Foundation




public class GCDSocketServer<T: GCDSocketAddress> : GCDSocket, GCDSocketPointerMangler {
  
  
  public let descriptor : GCDSocketDescriptor<T>
  public let backlog    : Int32
  public var accept     : ((Result<GCDSocket, GCDSocketError>) -> Void)? = nil
  public var bound      : (()->Void)? = nil
  
  private var accepting : Bool = false
  
  
  public init ( descriptor: GCDSocketDescriptor<T>, backlog: Int32 = 8 ) {
    
    self.descriptor = descriptor
    self.backlog    = backlog
    
    super.init(fd: descriptor.handle)
  }
  
  
  
  public override func resume() {
    
    accepting = true
    
    sockQ.async { [self] in
      
      let bres = rebound(from: descriptor.sockAddr) { saddr, slen in
        Darwin.bind(sockFD, saddr, slen)
      }
      
      if bres != 0 {
        accept? ( .failure( .bind(errno)) )
        accepting = false
        return
      }
      
      // execute a block of code when we sucesfully binf, for, e.g. chmod
      bound?()
      
      let lres = Darwin.listen(sockFD, backlog)
      if  lres != 0 {
        accept? ( .failure( .listen(errno)) )
        accepting = false
        return
      }
      
      
      
      while accepting {
        
        let clisockaddr = T()
        var cliaddrlen  = socklen_t(MemoryLayout<T>.size)
        
        let clisock = rebound(from: clisockaddr) { saddr, slen in
          Darwin.accept(sockFD, saddr, &cliaddrlen)
        }
        
        if clisock == -1 {
          accept? (.failure( .accept(errno)) )
          accepting = false
          break
        }
        
        accept?( .success(GCDSocket(fd: clisock) ) )
        
      }
    }
  }
  
  
  public func suspend() {
    accepting = false
  }
  
  public override func close() {
    accepting = false
    super.close()
  }
  
}
