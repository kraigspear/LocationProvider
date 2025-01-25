//
//  TestCases.swift
//  TestApp
//
//  Created by Kraig Spear on 1/26/25.
//

import SwiftUI

struct TestCase: Identifiable {
    let id = UUID()
    let title: String
    let steps: [String]
    let expectedOutcome: String
}

struct TestCasesView: View {
    @State private var currentPage = 0
    
    let testsCases = [
        TestCase(
            title: "Happy Path - Location Permission",
            steps: [
                "1. Launch the app",
                "2. Tap the 'Find Location' button",
                "3. When prompted, tap 'Allow' for location permissions"
            ],
            expectedOutcome: "App should successfully retrieve and display the current location"
        ),
        TestCase(
            title: "Denied Permission Path",
            steps: [
                "1. Launch the app",
                "2. Tap the 'Find Location' button",
                "3. When prompted, tap 'Don't Allow' for location permissions"
            ],
            expectedOutcome: "App should display an error message and provide instructions to enable permissions in Settings"
        ),
        TestCase(
            title: "Locations services turned off",
            steps: [
                "1. Turn off location services",
                "2. Launch App",
                "3. Tap find location button"
            ],
            expectedOutcome: "Error message indicating to turn on location permissions"
        ),
        TestCase(
            title: "Airplane Mode",
            steps: [
                "1. Turn on Airplane mode",
                "2. Launch App",
                "3. Tap find location button"
            ],
            expectedOutcome: "Error message indicating no network, airplane mode."
        )
    ]
    
    var body: some View {
        VStack {
            Text("Test Cases")
                .font(.largeTitle)
                .padding()
            
            TabView(selection: $currentPage) {
                ForEach(testsCases.indices, id: \.self) { index in
                    TestCaseView(instruction: testsCases[index], pageNumber: index + 1)
                        .tag(index)
                }
            }.tabViewStyle(PageTabViewStyle())
             .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}

#Preview("TestCases") {
    TestCasesView()
}
