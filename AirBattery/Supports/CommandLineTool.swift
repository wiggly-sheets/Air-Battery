//
//  CommandLineTool.swift
//  AirBattery
//
//  Created by apple on 2025/05/19.
//

import Foundation

class CommandLineTool {
    static func runAsRoot(_ command: String, completion: (() -> Void)? = nil) {
        let script = "do shell script \"\(command)\" with administrator privileges"
        var error: NSDictionary?
        
        if let scriptObject = NSAppleScript(source: script) {
            let _ = scriptObject.executeAndReturnError(&error)
            
            if error == nil {
                completion?()
            } else {
                print("Error executing command: \(String(describing: error))")
            }
        }
    }
    
    static let lowPowerRulePath = "/etc/sudoers.d/airbattery"

    static func lowPowerRuleInstalled() -> Bool {
        fd.fileExists(atPath: lowPowerRulePath)
    }

    // Installs a one-time sudoers rule so Low Power Mode can be toggled without a
    // password every time. The rule only allows the exact pmset lowpowermode
    // commands, not arbitrary root commands.
    static func installLowPowerRule() -> Bool {
        let user = NSUserName()
        guard user.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            print("⚠️ Unsupported user name for sudoers rule: \(user)")
            return false
        }
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a lowpowermode 0, /usr/bin/pmset -a lowpowermode 1"
        runAsRoot("/bin/echo '\(rule)' > /etc/sudoers.d/.airbattery && /bin/chmod 440 /etc/sudoers.d/.airbattery && /usr/sbin/visudo -cf /etc/sudoers.d/.airbattery && /bin/mv /etc/sudoers.d/.airbattery /etc/sudoers.d/airbattery")
        return lowPowerRuleInstalled()
    }

    static func setLowPowerMode(_ enabled: Bool) {
        if !lowPowerRuleInstalled() && !installLowPowerRule() { return }
        _ = process(path: "/usr/bin/sudo", arguments: ["-n", "/usr/bin/pmset", "-a", "lowpowermode", enabled ? "1" : "0"])
    }

    static func isInstalled() -> Bool {
        let attributes = try? fd.attributesOfItem(atPath: "/usr/local/bin/airbattery")
        return attributes?[.type] as? FileAttributeType == .typeSymbolicLink
    }
    
    static func install(action: (() -> Void)? = nil) {
        if let resourceURL = Bundle.main.resourceURL {
            let binPath = resourceURL.appendingPathComponent("abt").path
            if !fd.fileExists(atPath: "/usr/local/bin") {
                runAsRoot("/bin/mkdir -p /usr/local/bin;/bin/ln -s '\(binPath)' /usr/local/bin/airbattery") {
                    action?()
                }
            } else {
                runAsRoot("/bin/ln -s '\(binPath)' /usr/local/bin/airbattery") {
                    action?()
                }
            }
        }
    }
    
    static func uninstall(action: (() -> Void)? = nil) {
        runAsRoot("/bin/rm /usr/local/bin/airbattery") { action?() }
    }
}
