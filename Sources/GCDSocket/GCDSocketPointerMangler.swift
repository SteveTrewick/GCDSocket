import Foundation



/*
  today in "I am not typing that fugly monstrosity like 4 times"
  we have to a fucky pointer dance around a lot of the Darwin POSIX calls because we are
  not in a casually typed language like C. Anyway, here we go through the dance of casting
  through from a sockaddr_* to a sockaddr, so we can just do like
 
  let bres = rebound(from: descriptor.sockAddr) { saddr, slen in
    Darwin.bind(sockFD, saddr, slen)
  }
  
  which is only marginally less ugly but easier to grok
 
  oh, except for accept, because it wants a pointer for length, anyway
 
  I added this as a protocol with a default just becuase I was kinda bored TBH.
*/

protocol GCDSocketPointerMangler {
  func rebound <T: GCDSocketAddress> ( from addr: T, _ exec: (UnsafeMutablePointer<sockaddr>, socklen_t) -> Int32 ) -> Int32
}

extension GCDSocketPointerMangler {
  
  func rebound <T: GCDSocketAddress> ( from addr: T, _ exec: (UnsafeMutablePointer<sockaddr>, socklen_t) -> Int32 ) -> Int32 {
    
    var addr = addr
  
    return withUnsafeMutablePointer(to: &addr) { addrPointer in
      addrPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        exec ( sockaddrPtr, socklen_t(MemoryLayout<T>.size) )
      }
    }
  }
}
