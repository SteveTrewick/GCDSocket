import Foundation

/*
 GCDSocketServer is a subclass of GCDSocket which adds server functionality
 once the socket is bound and accepting it will call its 'accept' block
 with an initialised GCDSocket for each client connecting.
 
 it will also optionally run the block in 'bound' once it is sucessfully bound
 so you can (for example) run a chmod or similar if you're a domain socket,
 (which is exactly, in fact, why it's there) or do whatever stuff you might
 need if you're a TCP/UDP sock.
 
 GCDSocketServer will send any errors it might encounter to the 'accept' block
 
*/


public class GCDSocketServer<T: GCDSocketAddress> : GCDSocket, GCDSocketPointerMangler {
  
  
  public let descriptor : GCDSocketDescriptor<T>
  public let backlog    : Int32
  public var accept     : ((Result<GCDSocket, GCDSocketError>) -> Void)? = nil
  public var bound      : (()->Void)? = nil
  
  private var accepting : Bool = false
  
  
  public init ( descriptor: GCDSocketDescriptor<T>, backlog: Int32 = 8 ) {
    
    self.descriptor = descriptor
    self.backlog    = backlog
    
    super.init(sockFD: descriptor.handle)
  }
  
  
  /*
    notice that we rejected the resume method and replaced it with our own,
    this socket will not be doing any reading, it will be spawning legions
    of baby sockets so we don't want the dispatch source or the read handler
   
    we will however use the socket queue to fork our server off into the
    background.
    
  */
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
      
      // execute a block of code when we sucesfully bind, for, e.g. chmod
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
        
        accept?( .success(GCDSocket(sockFD: clisock) ) )
        
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
