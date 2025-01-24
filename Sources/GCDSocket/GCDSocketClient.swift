import Foundation


public class GCDSocketClient<T: GCDSocketAddress> : GCDSocket, GCDSocketPointerMangler {
  
  let descriptor : GCDSocketDescriptor<T>

  
  public init(descriptor: GCDSocketDescriptor<T> ) {
    self.descriptor = descriptor
    super.init(fd: descriptor.handle)
  }
  
  
  public func connect() {
  
    // start handler, connect, notify failiure
    
    resume()
    
    let conres = rebound(from: descriptor.sockAddr) { saddr, slen in
      Darwin.connect(descriptor.handle, saddr, slen)
    }
    
    if conres != 0 {
      if let handler = self.readHandler { handler (.failure( .connect(errno)) ) }
    }
  }
}
