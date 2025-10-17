//
//  File.swift
//  drinkdVaporServer
//
//  Created by Enzo Herrera on 8/7/25.
//

import Foundation
import Logging

enum Log {

    case general
    case error

    func log(_ msg: String, file: String = #file, line: Int = #line) {

        let fileName = (file as NSString).lastPathComponent

        switch self {
        case .general:
            let logging = Logger(label: "drinkdVaporServer")
            logging.info("[\(fileName):\(line)] - \(msg)")
        case .error:
            let logging = Logger(label: "drinkdVaporServer")
            logging.error("⚠️ [\(fileName):\(line)] - \(msg)")
        }

    }

}
