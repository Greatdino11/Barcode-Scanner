//
//  Barcode_ScannerApp.swift
//  Barcode Scanner
//
//  Created by Anmol Deepak on 3/27/24.
//

import SwiftUI
import Firebase

@main
struct Barcode_ScannerApp: App {
    init(){
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
