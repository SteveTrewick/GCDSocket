import Foundation


/*
 Basic ass socket using BSD sox and GCD, I know this should all be your fancy new
 async/await but later, m'kay
*/


public class GCDSocket {
  
  
  private       let FIONREAD : UInt          = 0x4004667f
  private       let sockQ    : DispatchQueue = DispatchQueue(label: "sockQ") // TODO: add attribs
  private       let readQ    : DispatchQueue = DispatchQueue(label: "readQ") // TODO: add attribs
  private       let source   : DispatchSourceRead!
  private (set) var sockFD   : Int32!
  
  public init(protoFam: Int32, sockType: Int32) {
    
    self.sockFD = Darwin.socket(protoFam, sockType, 0)
    self.source = DispatchSource.makeReadSource(fileDescriptor: sockFD, queue: sockQ)
  }
  
  
  public func connect (domain path: String ) -> Bool {  // TODO: better errors? there's a lot of them, add later
    
    var address = sockaddr_un()
    
    path.withCString { ptr in
      withUnsafeMutablePointer(to: &address.sun_path.0) { dest in
          _ = strcpy(dest, ptr)
      }
    }

    let conres = withUnsafePointer(to: &address) { addrBytes -> Int32 in
      addrBytes.withMemoryRebound(to: sockaddr.self, capacity: 1) { saddr in
        Darwin.connect(sockFD, saddr, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    
    return conres == 0
  }
  
  
  
  public func connect (localPort: UInt16) -> Bool {
    
    var address = sockaddr_in()
    
    address.sin_family      = sa_family_t(AF_INET)
    address.sin_port        = in_port_t( localPort.bigEndian )
    address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

    let conres = withUnsafePointer(to: &address) { addrBytes -> Int32 in
      addrBytes.withMemoryRebound(to: sockaddr.self, capacity: 1) { saddr in
        Darwin.connect(sockFD, saddr, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    
    return conres == 0
  }
  
  /*
    keeping this sync for now, we may need async as well, wait and see.
  */
  public func write (data: Data) {
    // NB we're aplatting this TODO: add (some) error handling
    _ = data.withUnsafeBytes { bytes in
      Darwin.write(sockFD, bytes.baseAddress, data.count)
    }
  }
  
  //MARK: async read handler
  
  public enum ReadError : Error {
    case hostGTFO, other
  }
  
  public var dataHandler : ((Result<Data, ReadError>) -> Void)? = nil
  
  
  public func resume() {
    
    source.setEventHandler { [self] in

      var result : Result<Data, ReadError>!
      
      var avail = Int(0)
      _         = ioctl(sockFD, FIONREAD, &avail)
      var buff  = [UInt8](repeating: 0x00, count: avail)
      let count = read (sockFD, &buff, avail)
      
      switch count {
        case   0              : result = .failure ( .hostGTFO); close(sockFD)
        case   Int.min...(-1) : result = .failure ( .other   ); close(sockFD)
        default               : result = .success ( Data(bytes: &buff, count: avail) )
      }
      
      readQ.async {
        if let handler = dataHandler {
          handler(result)
        }
      }
      
    }
    source.resume()
  }
  
}



