/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

#if os(macOS)
import Darwin
import os.log
private var logs: [String:OSLog] = [:]

let subsystem = "com.kiadstudios.swift-langsrv"

internal func log(_ message: String, category: String, _ args: Any...) {
    if #available(macOS 10.12, *) {
        var log: OSLog = logs[category] ?? OSLog(subsystem: subsystem, category: category)
        logs[category] = log

        if args != nil {
            let escaped = message.replacingOccurrences(of: "%@", with: "%{public}@")
            os_log(escaped, log: log, type: .default, args)
        }
        else {
            os_log(message, log: log, type: .default)
        }
    }
    else {
        // Implementation Note: This method is currently a big hack to just to get
        // any sort of logging output. This needs to get revamped and put into a 
        // file or something. Also, **VERY IMPORTANT**: the protocol talks over
        // stdout, so don't output anything there.

        fputs("category: \(category), message: \(message)\n", stderr)
    }
}

#endif