import Foundation

public enum GCDSocketError : Error {
  case hostGTFO, userGTFO,
       read(Int32),
       write(Int32), bytesDropped(Int),
       connect(Int32),
       bind(Int32), listen(Int32), accept(Int32)
}


public protocol GCDSocketAddress { init () }

extension sockaddr_un : GCDSocketAddress { }
extension sockaddr_in : GCDSocketAddress { }


public struct GCDSocketDescriptor <T : GCDSocketAddress> {
  let handle   : Int32
  let sockAddr : T
}


public class GCDSocket {
  
  public   let sockFD      : Int32
  public   var readHandler :((Result<Data, GCDSocketError>) -> Void)? = nil
  
  internal let FIONREAD    : UInt = 0x4004667f
  internal let sockQ       : DispatchQueue = DispatchQueue(label: "sockQ" )
  internal let source      : DispatchSourceRead
  
  
  public init ( fd: Int32, handler: ((Result<Data, GCDSocketError>) -> Void)? = nil ) {
    self.sockFD      = fd
    self.source      = DispatchSource.makeReadSource(fileDescriptor: sockFD, queue: sockQ)
    self.readHandler = handler
  }
  
  
  
  public func resume() {
    
    
    source.setEventHandler { [self] in
    
      var result : Result<Data, GCDSocketError>!
      
      var avail = Int(0)
      _         = ioctl ( sockFD, FIONREAD, &avail )
      var buff  = [UInt8](repeating: 0x00, count: avail)
      let count = read ( sockFD, &buff, avail )
      
      switch count {
        case   0 : result = .failure ( .hostGTFO    ); Darwin.close ( sockFD)
        case  -1 : result = .failure ( .read(errno) ); Darwin.close ( sockFD )
        
        default  : result = .success ( Data(bytes: &buff, count: avail) )
      }
      
      
      readHandler?(result)
      
    }
    source.resume()  // we definitely dont want to do this on a server
  }
  
  
  public func write(data: Data) {
    
    let wres = data.withUnsafeBytes { bytes in
      Darwin.write(sockFD, bytes.baseAddress, data.count)
    }
    
    guard wres == 0 else {
      if wres == -1         { readHandler?(.failure(.write(errno))) }
      if wres < data.count  { readHandler?(.failure(.bytesDropped(data.count - wres))) }
      return
    }
    
    
  }
  
  public func close() {
    Darwin.close(sockFD)
    readHandler?( .failure(.userGTFO) )
  }
  
}
