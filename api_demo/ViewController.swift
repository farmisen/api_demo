//
//  ViewController.swift
//  api_demo
//
//  Created by Fabrice Armisen on 10/1/17.
//  Copyright © 2017 Fabrice Armisen. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Alamofire
import SceneKit.ModelIO

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!

    private var apiNode: SCNNode?

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = SCNScene()

        let parameters = ["componentA": "05e7c0e3a195b75f0ced56f355ce1aa2",
                          "componentB": "6171a57ead7b8361f02cce80816d293d",
                          "scaffoldMesh1": "9ba748df8cbdee653a195edbe9b1ea05",
                          "cellHeight": 3,
                          "directOutput": true
        ] as [String: Any]

        self.getMeshUrl(parameters: parameters, completion: { url in
            guard let assetUrl = url else {
                print("Malformed url: \(url as Optional)")
                return
            }

            let asset = MDLAsset(url: assetUrl)
            guard let object = asset.object(at: 0) as? MDLMesh else {
                fatalError("Failed to get mesh from asset.")
            }

            self.apiNode = SCNNode(mdlObject: object)
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        //configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // on screen touch, create a node, give it a random color and place it at the hit test intersection
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        let results = sceneView.hitTest(touch.location(in: sceneView), types: [ARHitTestResult.ResultType.featurePoint])
        guard let hitFeature = results.last else {
            return
        }
        let hitTransform = SCNMatrix4(hitFeature.worldTransform)
        let hitPosition = SCNVector3Make(hitTransform.m41,
                hitTransform.m42,
                hitTransform.m43)

        let node = createNode()
        node.position = hitPosition
        node.geometry?.materials = [randomMaterial()]
        node.eulerAngles = randomOrientation()
        sceneView.scene.rootNode.addChildNode(node)
    }

    // MARK: - ARSCNViewDelegate

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else {
            return
        }

        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }

        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nRecoverable error"
        } else {
            sessionErrorMsg += "\nUnrecoverable error"
        }

        print(sessionErrorMsg)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("Session interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("Session interruption ended")
    }

    // MARK: Geometry helpers

    func createNode() -> SCNNode {
        if let node = self.apiNode {
            let clone = node.clone()
            clone.geometry = node.geometry?.copy() as? SCNGeometry
            let scale = (0.0001...0.0005).random()
            clone.scale = SCNVector3(scale, scale, scale)
            return clone
        } else {
            let boxGeometry = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.0)
            let box = SCNNode(geometry: boxGeometry)
            let scale = (0.05...0.1).random()
            box.scale = SCNVector3(scale, scale, scale)
            return box
        }
    }

    func randomOrientation() -> SCNVector3 {
        let twoPIRange =  (0...2 * Double.pi)
        return SCNVector3(twoPIRange.random() , twoPIRange.random() , twoPIRange.random() )
    }

    func randomMaterial() -> SCNMaterial {
        let color = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)
        let material = SCNMaterial()
        material.diffuse.contents = color
        return material
    }

    // MARK: Api helpers

    // Returns a local URL for a fetched mesh
    func getMeshUrl(parameters: [String: Any], completion: @escaping (URL?) -> Void) {
        fetchMeshData(parameters: parameters, completion: {
            assetData in
            guard let data = assetData else {
                print("Null data returned from the api")
                return
            }

            guard let objData = data["obj"] as? String else {
                print("No obj data returned from the api")
                return
            }

            let fileManager = FileManager.default
            let dir = fileManager.urls(for: FileManager.SearchPathDirectory.cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first!
            let fileurl = dir.appendingPathComponent("model.obj")
            try! objData.write(to: fileurl, atomically: true, encoding: String.Encoding.utf8)

            completion(fileurl)
        })
    }

    // Download and return the json data describing a mesh from the api
    func fetchMeshData(parameters: [String:Any], completion: @escaping ([String: Any]?) -> Void) {
        Alamofire.request(
                        URL(string: "https://studiobitonti.appspot.com/surfaceLattice")!,
                        method: .get,
                        parameters: parameters)
                .validate()
                .responseJSON { (response) -> Void in
                    guard response.result.isSuccess else {
                        print("Error while fetching remote mesh: \(response.result.error as Optional)")
                        completion(nil)
                        return
                    }

                    guard let data = response.result.value as? [String: Any] else {
                        print("Malformed mesh data received from api")
                        completion(nil)
                        return
                    }

                    completion(data)
                }
    }

}

extension ClosedRange where Bound: FloatingPoint {
    public func random() -> Bound {
        let range = self.upperBound - self.lowerBound
        let randomValue = (Bound(arc4random_uniform(UINT32_MAX)) / Bound(UINT32_MAX)) * range + self.lowerBound
        return randomValue
    }
}
