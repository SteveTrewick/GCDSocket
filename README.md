# GCDSocket

GCDSocket is a swift library that provides a simple interface to unix domain and 
local TCP/UDP client and server sockets.

GCD is an ancient technology at this point, but I needed a quick and lightweight 
library to poke some sockets (primarily domain sockets in my case) and this is what 
happened.

If you need anything more complex than hacking around local domain and IP4 sockets
this is not the library for you, you want something bigger, better, more sophisticated
and likely to be maintained after I get done with the current thing and get bored.


Anyway, let's have some examples


## Unix Domain Client

```swift

/*
  note that when I am connecting out I have the following running
  
  socat UNIX-LISTEN:./test_addr.sock,fork SYSTEM:"cat banner.txt; cat"
  socat TCP-LISTEN:1234,fork SYSTEM:"cat banner.txt ; cat"
 
  socat is also used to test the server with [unix|tcp]-connect:...
*/

let construct = GCDSocketConstructor()

let domainSocket = construct.domainSocketClient(path: "/Users/steve/Projects/UVC/test_addr.sock")

domainSocket.dataHandler = { result in
  switch result {
    case .failure(let error): print(error)
    case .success(let data ): print( String(data:data, encoding:.utf8) ?? "oof" )
  }
}

domainSocket.connect()
domainSocket.write ( data: "hello".data(using: .utf8)! )

RunLoop.current.run()

/*
The quick brown fox jumped over the lazy dog everyone clapped, except the dog, because he was lazy, also I don't think dogs can clap, because you know, hands?
hello
*/

```

## Local TCP Client

This is just exactly the same, but with a port number.

```swift

let localTCPSocket = construct.loacalSocketClient(port: 1234, type: .stream)

localTCPSocket.dataHandler = { result in
  switch result {
    case .failure(let error): print(error)
    case .success(let data ): print( String(data:data, encoding:.utf8) ?? "oof" )
  }
}
localTCPSocket.connect()

```

## Let's Build An Echo Server

This one is TCP but could just as easily be UDP or a Unix domain sock.

```swift

let localTCPServer = construct.localSocketServer(port: 4321, type: .stream)


localTCPServer.accept = { result in
  switch result {
    case .failure ( let error  ): print(error)
    case .success ( let socket ):
      
      // lets build an echo server!
      socket.dataHandler = { result in
        switch result {
          case .failure ( let error): print(error)
          case .success ( let data ): socket.write(data: data)
        }
      }
      socket.resume()
  }
}
localTCPServer.resume()


```

What if we want to get a bit more sophisticated, like building an intercepting proxy server
so we can, for instance, MITM macOS usbmuxd and snoop on all the fun things that are going 
on between the mac and the services on our iPhone? This one is obvioulsy a domain socket
version but you can do this with any of the sockets, though you may have to do some more
sophisticated things to properly track a proto, here we are just going to dump it to hex

## Intercepting Proxy Server

```swift

/*
  sudo mv /var/run/usbmuxd /var/run/usbmuxd_real
  and make sure to run this server as root as well
  
  don't forget to put usmuxd back when you are done!
*/


let helper = GCDSocketConstructor()
let server = helper.domainSocketServer(path: "/var/run/usbmuxd")


server.accept = { result in
  
  var clisock : GCDSocket!
  
  switch result {
      case .failure(let fail  ): print(fail)
      case .success(let socket): clisock = socket
  }
  
  let muxsock = helper.domainSocketClient(path: "/var/run/usbmuxd_real")
  
  clisock.dataHandler = { result in
    
    let hex = HexDump()
    
    switch result {
      
      case .failure(let _   ) : DispatchQueue.main.async { print("closed muxd: \(clisock.sockFD)") }
      case .success(let data) :
        
        DispatchQueue.main.async {
          print("client (\(clisock.sockFD)) -> usbmuxd (\(muxsock.sockFD)) : \(data.count) bytes")
          print(hex.dump(bytes: Array(data)) + "\n\n")
        }
        muxsock.write(data: data)
    }
  }
  
  
  muxsock.dataHandler = { result in
    
    let hex = HexDump()  // https://gist.github.com/SteveTrewick/d5be84b6125de321d035fa9497134856
    
    switch result {
      
      case .failure(let err)  : DispatchQueue.main.async { print("error: \(err)") }
      case .success(let data) :
      
        DispatchQueue.main.async {
          print("usbmuxd (\(muxsock.sockFD)) -> client (\(clisock.sockFD)) : \(data.count) bytes")
          print(hex.dump(bytes: Array(data)) + "\n\n")
        }
        clisock.write(data: data)
    }
  }
  
  muxsock.connect()
  clisock.resume()
  
}
server.bound = { chmod("/var/run/usbmuxd", 0o777) }
server.resume()


/*
client (32) -> usbmuxd (71) : 490 bytes
ea 01 00 00 01 00 00 00 08 00 00 00 06 00 00 00  ................
3c 3f 78 6d 6c 20 76 65 72 73 69 6f 6e 3d 22 31  <?xml.version="1
2e 30 22 20 65 6e 63 6f 64 69 6e 67 3d 22 55 54  .0".encoding="UT
46 2d 38 22 3f 3e 0a 3c 21 44 4f 43 54 59 50 45  F-8"?>.<!DOCTYPE
20 70 6c 69 73 74 20 50 55 42 4c 49 43 20 22 2d  .plist.PUBLIC."-
2f 2f 41 70 70 6c 65 2f 2f 44 54 44 20 50 4c 49  //Apple//DTD.PLI
53 54 20 31 2e 30 2f 2f 45 4e 22 20 22 68 74 74  ST.1.0//EN"."htt
70 3a 2f 2f 77 77 77 2e 61 70 70 6c 65 2e 63 6f  p://www.apple.co
6d 2f 44 54 44 73 2f 50 72 6f 70 65 72 74 79 4c  m/DTDs/PropertyL
69 73 74 2d 31 2e 30 2e 64 74 64 22 3e 0a 3c 70  ist-1.0.dtd">.<p
6c 69 73 74 20 76 65 72 73 69 6f 6e 3d 22 31 2e  list.version="1.
30 22 3e 0a 3c 64 69 63 74 3e 0a 09 3c 6b 65 79  0">.<dict>..<key
3e 42 75 6e 64 6c 65 49 44 3c 2f 6b 65 79 3e 0a  >BundleID</key>.
09 3c 73 74 72 69 6e 67 3e 63 6f 6d 2e 6f 62 73  .<string>com.obs
70 72 6f 6a 65 63 74 2e 6f 62 73 2d 73 74 75 64  project.obs-stud
69 6f 3c 2f 73 74 72 69 6e 67 3e 0a 09 3c 6b 65  io</string>..<ke
79 3e 43 6c 69 65 6e 74 56 65 72 73 69 6f 6e 53  y>ClientVersionS
74 72 69 6e 67 3c 2f 6b 65 79 3e 0a 09 3c 73 74  tring</key>..<st
72 69 6e 67 3e 6f 62 73 2d 69 6f 73 2d 63 61 6d  ring>obs-ios-cam
65 72 61 2d 70 6c 75 67 69 6e 3c 2f 73 74 72 69  era-plugin</stri
6e 67 3e 0a 09 3c 6b 65 79 3e 4d 65 73 73 61 67  ng>..<key>Messag
65 54 79 70 65 3c 2f 6b 65 79 3e 0a 09 3c 73 74  eType</key>..<st
72 69 6e 67 3e 4c 69 73 74 44 65 76 69 63 65 73  ring>ListDevices
3c 2f 73 74 72 69 6e 67 3e 0a 09 3c 6b 65 79 3e  </string>..<key>
50 72 6f 67 4e 61 6d 65 3c 2f 6b 65 79 3e 0a 09  ProgName</key>..
3c 73 74 72 69 6e 67 3e 4f 42 53 3c 2f 73 74 72  <string>OBS</str
69 6e 67 3e 0a 09 3c 6b 65 79 3e 6b 4c 69 62 55  ing>..<key>kLibU
53 42 4d 75 78 56 65 72 73 69 6f 6e 3c 2f 6b 65  SBMuxVersion</ke
79 3e 0a 09 3c 69 6e 74 65 67 65 72 3e 33 3c 2f  y>..<integer>3</
69 6e 74 65 67 65 72 3e 0a 3c 2f 64 69 63 74 3e  integer>.</dict>
0a 3c 2f 70 6c 69 73 74 3e 0a                    .</plist>.

... and so on
*/
```
