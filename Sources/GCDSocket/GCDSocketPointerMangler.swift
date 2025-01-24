import Foundation


protocol GCDSocketPointerMangler {
  func rebound <T:GCDSocketAddress> ( from addr: T, _ exec: (UnsafeMutablePointer<sockaddr>, socklen_t) -> Int32 ) -> Int32
}

extension GCDSocketPointerMangler {
  
  func rebound <T:GCDSocketAddress> ( from addr: T, _ exec: (UnsafeMutablePointer<sockaddr>, socklen_t) -> Int32 ) -> Int32 {
    
    var addr = addr
  
    return withUnsafeMutablePointer(to: &addr) { addrPointer in
      addrPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        exec ( sockaddrPtr, socklen_t(MemoryLayout<T>.size) )
      }
    }
  }
}
