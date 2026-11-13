//
//  Item.swift
//  AnotherCloudKitDemo
//
//  Created by Tiffany Tan on 1/8/26.
//

import Foundation
import SwiftData


    
    struct Reminder: Identifiable {
        let id = UUID()
        var title: String
        var dueDate: Date
        var subject: String
        var isCompleted: Bool
        
        
        
        init(title: String, dueDate: Date, subject: String, isCompleted: Bool) {
            self.title = title
            self.dueDate = dueDate
            self.subject = subject
            self.isCompleted = isCompleted
            
        }
    }
    
    

