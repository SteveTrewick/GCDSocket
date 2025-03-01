import Foundation


/*
  various types of errors that can occur
*/
public enum GCDSocketError : Error {
  
  case hostGTFO, userGTFO,
       read(Int32),
       write(Int32), bytesDropped(Int),
       connect(Int32),
       bind(Int32), listen(Int32), accept(Int32)
}


/*
  we really have to at least sort of constrain the wild generic param on GCDSock and the descriptor,
  add more as required
*/
public protocol GCDSocketAddress { init () }

extension sockaddr_un : GCDSocketAddress { }
extension sockaddr_in : GCDSocketAddress { }


/*
  wrapper for our handle and sockaddr
*/
public struct GCDSocketDescriptor <T : GCDSocketAddress> {
  let handle   : Int32
  let sockAddr : T
}


/*
  base GCDSocket class, the client and server sockets inherit from this class.
  NB that the socket only runs one queue so if you have substantial processing
  to do in yur handler, you may wish to marshall it off somewhere else.
 
  reads, writes and closes are all done async on the socket's queue to prevent
  non queue access stomping on the file descriptor.
 
  errors are directed to the handler on the same queue.
 
  basic straightforward GCD stuff from the olden days, we set up a dispatch source
  and when data comes in we read it and pass it on, simples, mostly.
 
  wrinkles include using FIONREAD to get the amount of data that is actually
  available in the read, it is of course #defined in the c headers so not
  imported to swift
 
*/

public class GCDSocket {
  
  public   let sockFD      : Int32
  public   var dataHandler : ((Result<Data, GCDSocketError>) -> Void)? = nil
  
  internal let FIONREAD    : UInt = 0x4004667f
  internal let sockQ       : DispatchQueue = DispatchQueue(label: "sockQ" )
  internal let source      : DispatchSourceRead
  
  
  public init ( sockFD: Int32, handler: ((Result<Data, GCDSocketError>) -> Void)? = nil ) {
    self.sockFD      = sockFD
    self.source      = DispatchSource.makeReadSource ( fileDescriptor: sockFD, queue: sockQ )
    self.dataHandler = handler
  }
  
  
  
  public func resume() {
    
    
    source.setEventHandler { [self] in
    
      var result : Result<Data, GCDSocketError>!
      
      var avail = Int(0)
      _         = ioctl ( sockFD, FIONREAD, &avail )
      var buff  = [UInt8](repeating: 0x00, count: avail)
      let count = read ( sockFD, &buff, avail )
      
      switch count {  // NB that if we don't close the sock when we error out, we get a nasty spinlock
        case   0 : result = .failure ( .hostGTFO    ); Darwin.close ( sockFD )
        case  -1 : result = .failure ( .read(errno) ); Darwin.close ( sockFD )
        
        default  : result = .success ( Data(bytes: &buff, count: avail) )
      }
      
      dataHandler?(result)
      
    }
    source.resume()
  }
  
  
  /*
    write and close both touch sockFD which is managed by the dispatch source, so we
    wrap these ops in the queue as well.
  */

  public func write ( data: Data ) {
    
    sockQ.async { [self] in
      let wres = data.withUnsafeBytes { bytes in
        Darwin.write(sockFD, bytes.baseAddress, data.count)
      }
      
      guard wres == 0 else {
        if wres == -1         { dataHandler?(.failure(.write(errno))) }
        if wres < data.count  { dataHandler?(.failure(.bytesDropped(data.count - wres))) }
        return
      }
    }
  }
  
  public func close() {
    sockQ.async { [self] in
      Darwin.close ( sockFD )
      dataHandler? ( .failure(.userGTFO) )
    }
  }
  
}
