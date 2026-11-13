//
//  Item.swift
//  AnotherCloudKitDemo
//
//  Created by Tiffany Tan on 1/8/26.
//

import SwiftUI

// Colour options the user can pick from when creating a subject
enum SubjectColor: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, purple, pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }
}

struct Subject: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var color: SubjectColor
}

struct Reminder: Identifiable {
    let id = UUID()
    var title: String
    var dueDate: Date
    var subject: Subject
    var isCompleted: Bool = false
}

