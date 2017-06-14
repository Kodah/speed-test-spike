

import Foundation
import UIKit
import Enamel


class ViewController: UIViewController, URLSessionDelegate, URLSessionDataDelegate, SimplePingDelegate {
    
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var pingLabel: UILabel!
    
    var pinger: SimplePing?
    var canStartPinging = false
    
    var pingSendTime: CFAbsoluteTime!
    var pingRespondTime: CFAbsoluteTime!
    var startTime: CFAbsoluteTime!
    var stopTime: CFAbsoluteTime!
    var bytesReceived: CGDataSize!
    var speeds: [CGFloat] = []
    var speedTestCompletionHandler: ((_ megabytesPerSecond: CGFloat?, _ error: NSError?) -> ())!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func runTest(_ sender: Any) {
        
        pingHost()
        
        testDownloadSpeedWithTimout(timeout: 10) { [unowned self] (megabytesPerSecond, error) -> () in
            print("Recieved: \(self.bytesReceived!)")
            
            async(on: .main) {
                
                let pointsToAverage = self.speeds.count / 4
                
                let toPrint = self.speeds.sorted(by: >)[0...pointsToAverage].reduce(0.0, +) / pointsToAverage.cg
                self.label.textColor = UIColor.green
                self.label.text = "\(toPrint.floor(places: 2))Mbps"
            }
            
        }
    }
    
    
    func pingHost() {
        canStartPinging = false
        pinger = SimplePing(hostName: "dm04bryf4ev02.cloudfront.net")
        pinger?.delegate = self
        pinger?.start()
        
        repeat {
            if (canStartPinging) {
                pinger?.send(with: nil)
            }
            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: (NSDate.distantFuture as NSDate) as Date)
        } while(pinger != nil)
    }
    
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        canStartPinging = true
    }
    
    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        pingSendTime = CFAbsoluteTimeGetCurrent()
    }
    
    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        pingRespondTime = CFAbsoluteTimeGetCurrent()
        
        let pingInMS = (pingRespondTime - pingSendTime)*1000
        pingLabel.text = "ping: \(pingInMS.rounded(.down))ms"
        self.pinger = nil
        
    }
    
    func testDownloadSpeedWithTimout(timeout: TimeInterval, completionHandler:@escaping (_ megabytesPerSecond: CGFloat?, _ error: NSError?) -> ()) {
        let url = NSURL(string: "http://dm04bryf4ev02.cloudfront.net/100MB.zip")!
        
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = timeout
        
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        bytesReceived = 0.B
        speeds = []
        speedTestCompletionHandler = completionHandler
        
        session.dataTask(with: url as URL).resume()
        startTime = CFAbsoluteTimeGetCurrent()
        stopTime = startTime
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bytesReceived = bytesReceived + data.count.B
        stopTime = CFAbsoluteTimeGetCurrent()
        
        let elapsed = stopTime - startTime
        
        let speed = (bytesReceived.B.cg / elapsed.cg).B.mb
        speeds.append(speed)
        
        
        async(on: .main) {
            self.label.textColor = UIColor.orange
            self.label.text = "\(speed.floor(places: 2))Mbps"
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let e = error as NSError?
        let elapsed = stopTime - startTime
        guard elapsed != 0 && (error == nil || (e?.domain == NSURLErrorDomain && e?.code == NSURLErrorTimedOut)) else {
            speedTestCompletionHandler(nil, e)
            return
        }
        
        let speed = bytesReceived.mb / elapsed.cg
        speedTestCompletionHandler(speed, nil)
    }
    
}

public extension CGDataSize {
    public var b: CGFloat {
        switch self {
        case .B(let $): return $ * 8
            
        case .kB(let $): return $ * 1000 * 8
        case .MB(let $): return $ * 1000_000 * 8
        case .GB(let $): return $ * 1000_000_000 * 8
        case .TB(let $): return $ * 1000_000_000_000.0 * 8
            
        case .KiB(let $): return $ * 1024 * 8
        case .MiB(let $): return $ * 1_048_576 * 8
        case .GiB(let $): return $ * 1_073_741_824 * 8
        case .TiB(let $): return $ * 1_099_511_627_776.0 * 8
        }
    }
    
    public var mb: CGFloat {
        switch self {
        case .B(let $): return $ / 125000
            
        case .kB(let $): return $ / 0.125
        case .MB(let $): return $ * 8
        case .GB(let $): return $ * 8000
        case .TB(let $): return $ * 8000000
        default: return -1
        }
    }
}
