//
//  SpiritLevelVC.swift
//  Unified
//
//  Created by Angus Yi on 2021/7/5.
//  Copyright © 2021 August. All rights reserved.
//

import UIKit
import CoreMotion
import SpriteKit

class SpiritLevelVC: KFBaseViewController, AVCaptureMetadataOutputObjectsDelegate {
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var degreeView: UIView!
    @IBOutlet weak var degreeLabel: UILabel!
    
    var isSlideUP = false
    
    let deviceMotionManager = DeviceMotionManager.shared
    private var benchMark = 0
    
    private var captureDevice: AVCaptureDevice?
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("spirit_level_title", comment: "")
        if isSlideUP {
            self.navigationItem.leftBarButtonItem = nil
            self.setCustomRightButtom(target: self, action: #selector(dismissVC), imageName: "btn_nav_x")
        }
        
        degreeView.roundCorners(radius: 12)
        
        deviceMotionManager.manager?.accelerometerUpdateInterval = 0.2
        deviceMotionManager.manager?.startAccelerometerUpdates(to: OperationQueue.main, withHandler: { (accData, error) in
            if let accData = accData {
                self.outputAccData(accData: accData)
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        openCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        deviceMotionManager.manager?.stopDeviceMotionUpdates()
    }
    
    @objc private func dismissVC() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    private func openCamera() {
        guard let captureDev = AVCaptureDevice.default(for: .video) else {
            print("[SpiritLevelVC] AVCaptureDevice error.")
            return
        }
        
        do {
            captureDevice = captureDev
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            captureSession = AVCaptureSession()
            captureSession!.addInput(input)
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession!.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [.dataMatrix, .qr]
        } catch {
            print("[SpiritLevelVC] AVCaptureDeviceInput error.")
            return
        }
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = UIScreen.main.bounds
        cameraView.layer.addSublayer(videoPreviewLayer!)
        
        captureSession!.startRunning()
    }
    
    private func outputAccData(accData: CMAccelerometerData) {
        let acceleration = accData.acceleration
        let x = acceleration.x
        let y = acceleration.y
        
        let accInXYDegree: Double = atan2(x, y) * 180 / .pi
        let xyDegree360Format = scaleTo360Format(xyDegree: Int(accInXYDegree))
        setBenchMark(degree: xyDegree360Format)
        let displayDegree = xyDegree360Format - benchMark
        
        degreeLabel.text = "\(displayDegree)°"
        degreeView.backgroundColor = UIColor(red: 38/255, green: 72/255, blue: 109/255, alpha: 0.8)
        if displayDegree == 0 {
            degreeView.backgroundColor = UIColor(red: 91/255, green: 202/255, blue: 78/255, alpha: 0.8)
        }
        
        drawLineThroughCenter(degree: xyDegree360Format)
    }
    
    private func setBenchMark(degree: Int) {
        if degree < 20 {
            benchMark = 0
        } else if degree < 110 && degree > 70 {
            benchMark = 90
        } else if degree < 200 && degree > 160 {
            benchMark = 180
        } else if degree < 290 && degree > 250 {
            benchMark = 270
        } else if degree > 340 {
            benchMark = 360
        }
    }
    
    private func scaleTo360Format(xyDegree: Int) -> Int {
        // -180 ~ 180
        var scaledDegree: Int = 0
        if xyDegree > 0 {
            scaledDegree = 180 - xyDegree - 1
        }
        
        if xyDegree < 0 {
            scaledDegree = 180 - xyDegree
        }
        return scaledDegree
    }
    
    private func outputAttitudeData(attitude: CMAttitude) {
        let pitch = attitude.pitch
        let yaw = attitude.yaw
        let pitchDegree = pitch * (180/Double.pi)
        var degree = pitchDegree >= 0 ? Int(90 - pitchDegree) : Int(90 + pitchDegree)
        degreeLabel.text = "\(degree)°"
        degreeView.backgroundColor = UIColor(red: 38/255, green: 72/255, blue: 109/255, alpha: 0.8)
        if degree == 0 {
            degreeView.backgroundColor = UIColor(red: 91/255, green: 202/255, blue: 78/255, alpha: 0.8)
        }
        
        if yaw > 0 {
            degree = -degree
        }
        drawLineThroughCenter(degree: degree)
    }
    
    private func drawLineThroughCenter(degree: Int) {
        let path = UIBezierPath()
        var diffX: CGFloat = 0
        var diffY: CGFloat = 0
        var topPoint: CGPoint = CGPoint(x: 0, y: 0)
        var bottomPoint: CGPoint = CGPoint(x: 0, y: 0)
        if degree < 90 || (degree > 180 && degree < 270) {
            diffX = CGFloat(tan(Float(degree) * .pi/180) * Float(contentView.bounds.midY))
            diffY = contentView.bounds.minY
            topPoint = CGPoint(x: CGFloat(contentView.bounds.midX) + diffX, y: CGFloat(contentView.bounds.minY))
            bottomPoint = CGPoint(x: CGFloat(contentView.bounds.midX) - diffX, y: CGFloat(contentView.bounds.maxY))
            if diffX > contentView.bounds.midX {
                diffY = CGFloat(Float(contentView.bounds.midX) * tan(Float(90 - degree) * .pi/180))
                topPoint = CGPoint(x: CGFloat(contentView.bounds.maxX), y: CGFloat(contentView.bounds.midY) - diffY)
                bottomPoint = CGPoint(x: CGFloat(contentView.bounds.minX), y: CGFloat(contentView.bounds.midY) + diffY)
            }
        } else if degree == 90 || degree == 270 {
            diffX = contentView.bounds.maxX
            diffY = contentView.bounds.midY
            topPoint = CGPoint(x: CGFloat(contentView.bounds.minX), y: CGFloat(contentView.bounds.midY))
            bottomPoint = CGPoint(x: CGFloat(contentView.bounds.maxX), y: CGFloat(contentView.bounds.midY))
        } else if (degree > 90 && degree < 180) || (degree > 270) {
            diffX = -CGFloat(tan(Float(degree) * .pi/180) * Float(contentView.bounds.midY))
            topPoint = CGPoint(x: CGFloat(contentView.bounds.midX) + diffX, y: CGFloat(contentView.bounds.maxY))
            bottomPoint = CGPoint(x: CGFloat(contentView.bounds.midX) - diffX, y: CGFloat(contentView.bounds.minY))
            if diffX > contentView.bounds.midX {
                diffY = -CGFloat(Float(contentView.bounds.midX) * tan(Float(degree - 90) * .pi/180))
                topPoint = CGPoint(x: CGFloat(contentView.bounds.maxX), y: CGFloat(contentView.bounds.midY) - diffY)
                bottomPoint = CGPoint(x: CGFloat(contentView.bounds.minX), y: CGFloat(contentView.bounds.midY) + diffY)
            }
        }
        
        path.move(to: topPoint)
        path.addLine(to: bottomPoint)
        
        contentView.layer.sublayers = nil
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        if degree == 0 || degree == 90 || degree == 180 || degree == 270 {
            shapeLayer.strokeColor =  UIColor.green.cgColor
        } else {
            shapeLayer.strokeColor =  UIColor.blueDlink.cgColor
        }
        shapeLayer.lineWidth = 2
        if degree != 0 && degree != 90 && degree != 180 && degree != 270 {
            shapeLayer.lineDashPattern = [12, 8]
        }
        
        contentView.layer.insertSublayer(shapeLayer, at: UInt32(Int(contentView.layer.sublayers?.count ?? 0)))
    }
    
}

extension SpiritLevelVC {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let captureDev = captureDevice else {
            print("[SpiritLevelVC] AVCaptureDevice error.")
            return
        }
        
        guard let touchPoint = touches.first else { return }
        
        if !captureDev.isFocusModeSupported(.continuousAutoFocus)
            || !captureDev.isFocusPointOfInterestSupported {
            return
        }
        
        do {
            try captureDev.lockForConfiguration()
            
            let point = touchPoint.location(in: cameraView)
            let x = point.y / cameraView.frame.size.height
            let y = 1.0 - point.x / cameraView.frame.size.width
            let focusPoint = CGPoint(x: x, y: y)

            captureDev.focusPointOfInterest = focusPoint
            captureDev.focusMode = .continuousAutoFocus
            
            captureDev.unlockForConfiguration()
        } catch {
            print("[SpiritLevelVC] touchesBegan error.")
            return
        }
    }
}
