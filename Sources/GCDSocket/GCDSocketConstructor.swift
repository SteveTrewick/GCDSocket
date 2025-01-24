import Foundation


/*
 
 here we can construct, to our black heart's content the various bits and bobs of the
 GCDSocket fam, they should be fairly self explanatory, but still, I have to write docs
 one day, so ...
 
 one thing to note is that as of the moment this library only supports unix domain and local tcp/ip
 sockets and I have no current plans to change that, if you need something else, you should be using
 a better library.  THis is just for hacking around on your local system and mugging things like
 usbmuxd, which is what I wrote for originally, TBH
 
*/


public struct GCDSocketConstructor {
  
  /*
    SOCK_STREAM and SOCK_DGRAM for ip sockets
  */
  public enum SockType {
    case stream, datagram
  }
  
  
  public init() {}
  
  
  /*
    construct a domain socket descriptor from a path
  */
  public func domainSocket ( path: String ) -> GCDSocketDescriptor<sockaddr_un> {
    GCDSocketDescriptor (
      handle  : socket(AF_UNIX, SOCK_STREAM, 0),
      sockAddr: domainaddr ( path: path )
    )
  }
  
  /*
    construct a domain socket client from a path, the socket is not connected or running,
    it remains quiescent, awaiting your no doubt malicious attention
  */
  public func domainSocketClient ( path: String ) -> GCDSocketClient<sockaddr_un> {
    GCDSocketClient (
      descriptor: domainSocket(path: path)
    )
  }
  
  /*
    construct a whole heckin unix domain socket server from just. a. path.
    bargain of the century, I tell you
  */
  public func domainSocketServer ( path: String ) -> GCDSocketServer<sockaddr_un> {
    GCDSocketServer (
      descriptor: domainSocket(path: path)
    )
  }
  
  
  /*
    construct a local TCP/UDP socket descriptor
  */
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
  
  /*
    construct an actual GCDSocketClient given just the local port and type,
    as with the domain client, it will laze around doing nothing you .connect() it
  */
  public func loacalSocketClient ( port: UInt16, type: SockType ) -> GCDSocketClient<sockaddr_in> {
    GCDSocketClient (
      descriptor: localSocket(port: port, type: type)
    )
  }
  
  /*
    construct a living, breathing TCP/UDP server on a local port for your own twisted amusement
    don't forget to .resume() it though or it will just lie around grumbling
  */
  public func localSocketServer ( port: UInt16, type: SockType ) -> GCDSocketServer<sockaddr_in> {
    GCDSocketServer (
      descriptor: localSocket (port: port, type: type)
    )
  }
  
  
  /*
    utility funcs for building the sockaddrs
  */
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
