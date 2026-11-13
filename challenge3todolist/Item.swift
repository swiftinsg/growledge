//
//  Item.swift
//  challenge3todolist
//
//  Created by Tiffany Tan on 13/11/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
