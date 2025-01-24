import Foundation

public struct GCDSocketConstructor {
  
  public enum SockType {
    case stream, datagram
  }
  
  
  public init() {}
  
  
  public func domainSocket(path: String) -> GCDSocketDescriptor<sockaddr_un> {
    GCDSocketDescriptor (
      handle  : socket(AF_UNIX, SOCK_STREAM, 0),
      sockAddr: domainaddr ( path: path )
    )
  }
  
  
  public func domainSocketClient ( path: String ) -> GCDSocketClient<sockaddr_un> {
    GCDSocketClient (
      descriptor: domainSocket(path: path)
    )
  }
  
  public func domainSocketServer ( path: String ) -> GCDSocketServer<sockaddr_un> {
    GCDSocketServer (
      descriptor: domainSocket(path: path)
    )
  }
  
  public func localSocket ( port: UInt16, type: SockType ) -> GCDSocketDescriptor<sockaddr_in> {
    
    func sock(of type: SockType) -> Int32 {
      switch type {
        case .stream  : return socket(AF_INET, SOCK_STREAM, 0)
        case .datagram: return socket(AF_INET, SOCK_DGRAM,  0)
      }
    }
    
    return GCDSocketDescriptor (
      handle  : sock(of: type),
      sockAddr: localaddr(fam: AF_INET, port: port)
    )
    
  }
  
  public func loacalSocketClient ( port: UInt16, type: SockType ) -> GCDSocketClient<sockaddr_in> {
    GCDSocketClient (
      descriptor: localSocket(port: port, type: type)
    )
  }
  
  
  public func localSocketServer ( port: UInt16, type: SockType ) -> GCDSocketServer<sockaddr_in> {
    GCDSocketServer (
      descriptor: localSocket (port: port, type: type)
    )
  }
  
  public func localaddr ( fam: Int32, port: in_port_t ) -> sockaddr_in {
    
    var sockaddr = sockaddr_in()

    sockaddr.sin_family      = sa_family_t(fam)
    sockaddr.sin_port        = port.bigEndian
    sockaddr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
    
    return sockaddr
  }

  
  
  func domainaddr ( path: String ) -> sockaddr_un {
    
    var address = sockaddr_un()
    
    path.withCString { ptr in
      withUnsafeMutablePointer(to: &address.sun_path.0) { dest in
          _ = strcpy(dest, ptr)
      }
    }
    return address
  }

}
