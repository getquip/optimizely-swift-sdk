/****************************************************************************
 * Copyright 2017-2018, Optimizely, Inc. and contributors                   *
 *                                                                          *
 * Licensed under the Apache License, Version 2.0 (the "License");          *
 * you may not use this file except in compliance with the License.         *
 * You may obtain a copy of the License at                                  *
 *                                                                          *
 *    http://www.apache.org/licenses/LICENSE-2.0                            *
 *                                                                          *
 * Unless required by applicable law or agreed to in writing, software      *
 * distributed under the License is distributed on an "AS IS" BASIS,        *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
 * See the License for the specific language governing permissions and      *
 * limitations under the License.                                           *
 ***************************************************************************/

import UIKit
import Optimizely
#if os(iOS)
import Amplitude_iOS
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var optimizely: OptimizelyManager?
    
    // generate random user ID on each app load
    let userId = String(Int(arc4random_uniform(300000)))
    
    // customizable settings
    let datafileName = "demoTestDatafile"
    let experimentKey = "background_experiment"
    let eventKey = "sample_conversion"
    let attributes = ["browser_type": "safari"]
    let sdkKey = "FCnSegiEkRry9rhVMroit4"
    
    var storyboard: UIStoryboard {
        #if os(iOS)
        return UIStoryboard(name: "iOSMain", bundle: nil)
        #else
        return UIStoryboard(name: "tvOSMain", bundle: nil)
        #endif
    }
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        
        // initialize SDK in one of these two ways:
        // (1) asynchronous SDK initialization (RECOMMENDED)
        //     - fetch a JSON datafile from the server
        //     - network delay, but the local configuration is in sync with the server experiment settings
        // (2) synchronous SDK initialization
        //     - initialize immediately with the given JSON datafile or its cached copy
        //     - no network delay, but the local copy is not guaranteed to be in sync with the server experiment settings
        
        initializeOptimizelySDKAsynchronous()
        //initializeOptimizelySDKSynchronous()
    }
    
    func initializeOptimizelySDKAsynchronous() {
        
        // customization example (optional)
        let customLogger = makeCustomLogger()
        
        optimizely = OptimizelyManager(sdkKey: sdkKey,
                                       logger: customLogger,
                                       periodicDownloadInterval:60)

        
        _ = optimizely?.notificationCenter.addDatafileChangeNotificationListener(datafileListener: { (data) in
            DispatchQueue.main.async {
                let alert = UIAlertView(title: "Datafile change", message: "something changed.", delegate: nil, cancelButtonTitle: "cancel")
                alert.show()
            }
        })
        // initialize Optimizely Client from a datafile download
        optimizely!.initializeSDK { result in
            switch result {
            case .failure(let error):
                print("Optimizely SDK initiliazation failed: \(error)")
                self.optimizely = nil
            case .success:
                print("Optimizely SDK initialized successfully!")
            }
            
            DispatchQueue.main.async {
                self.setRootViewController(optimizelyManager: self.optimizely)
            }
        }
    }
    
    func initializeOptimizelySDKSynchronous() {
        guard let localDatafilePath = Bundle(for: self.classForCoder).path(forResource: datafileName, ofType: "json") else {
            fatalError("Local datafile cannot be found")
        }
        
        // customization example (optional)
        let customLogger = makeCustomLogger()
        
        optimizely = OptimizelyManager(sdkKey: sdkKey,
                                       logger: customLogger)

        do {
            let datafileJSON = try String(contentsOfFile: localDatafilePath, encoding: .utf8)
            try optimizely!.initializeSDK(datafile: datafileJSON)
            print("Optimizely SDK initialized successfully!")
        } catch {
            print("Optimizely SDK initiliazation failed: \(error)")
            optimizely = nil
        }
        
        setRootViewController(optimizelyManager: self.optimizely)
    }
    
    func setRootViewController(optimizelyManager: OptimizelyManager?) {
        guard let optimizely = optimizely else {
            openFailureView()
            return
        }
        
        do {
            let variationKey = try optimizely.activate(experimentKey: experimentKey,
                                                       userId: userId,
                                                       attributes: attributes)
            openVariationView(optimizelyManager: optimizely, variationKey: variationKey)
        } catch OptimizelyError.experimentNotParticipated {
            print("Optimizely SDK activation cannot map this user to experiemnt")
            openVariationView(optimizelyManager: optimizely, variationKey: nil)
        } catch {
            print("Optimizely SDK activation failed: \(error)")
            openFailureView()
        }
    }
    

    func makeCustomLogger() -> OPTLogger {
        class Logger : OPTLogger {
            static var level:OptimizelyLogLevel?
            static var logLevel: OptimizelyLogLevel {
                get {
                    if let level = level {
                        return level
                    }
                    return .all
                }
                set {
                    if let _ = level {
                        // already set.
                    }
                    else {
                        level = newValue
                    }
                }
            }
            
            required init() {
                
            }
            
            func log(level: OptimizelyLogLevel, message: String) {
                if level.rawValue <= Logger.logLevel.rawValue {
                    print("🐱 - [\(level.name)] Kitty - \(message)")
                }
            }
            
        }
        
        return Logger()
    }

    func openVariationView(optimizelyManager: OptimizelyManager?, variationKey: String?) {
        let variationViewController = storyboard.instantiateViewController(withIdentifier: "VariationViewController") as! VariationViewController
        
        variationViewController.eventKey = eventKey
        variationViewController.userId = userId
        variationViewController.optimizelyManager = optimizelyManager
        variationViewController.variationKey = variationKey
        
        window?.rootViewController = variationViewController
    }
    
    func openFailureView() {
        window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "FailureViewController")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        NotificationCenter.default.post(name: NSNotification.Name("OPTLYbackgroundFetchDone"), object: nil)
        completionHandler(.newData)
    }
}
