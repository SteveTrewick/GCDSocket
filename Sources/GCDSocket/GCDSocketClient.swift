import Foundation


/*
  a sub class of GCDSocket that adds a connect method
 
  GCDSocket sub classes must be initialised with a GCDSocketDescriptor
  containing an initialised socket handle and a populated sockaddr_[un|in]
 
  you can get these from the helper API or build them yourself if you're
  in the mood or you just hate yourself.
 
  before connecting, GCDSocketClient starts the dispatch source so we dont miss any data
 
  upon successful connection GCDSocketClient optionally runs a block stored in the
  'connected' property in case there's anything you want doing straight away, but the method
  is synchronous anyway, so you can just wait.
 
  you might be stuffing it in a collection for later though, so, there you go, just in case.
 
  oh, GCDSocketPointerMangler provides the 'rebound' method as a default implementation
  of a protocol, just for funsies
 
  GCDSocketClient will send any errors it encounters to the dataHandler block
 
*/

public class GCDSocketClient<T: GCDSocketAddress> : GCDSocket, GCDSocketPointerMangler {
  
  public let descriptor : GCDSocketDescriptor<T>
  public var connected: (()->Void)? = nil
  
  
  public init(descriptor: GCDSocketDescriptor<T> ) {
    self.descriptor = descriptor
    super.init(sockFD: descriptor.handle)
  }
  
  
  public func connect() {
  
    // start handler, connect, notify failiure
    
    resume()
    
    sockQ.async { [self] in
      
      let conres = rebound(from: descriptor.sockAddr) { saddr, slen in
        Darwin.connect(descriptor.handle, saddr, slen)
      }
      
      if conres != 0 {
        if let handler = dataHandler { handler (.failure( .connect(errno)) ) }
      }
      else {
        connected?()
      }
  }
  }
}
