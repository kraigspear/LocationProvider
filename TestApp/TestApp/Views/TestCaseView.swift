//
//  InstructionPageView.swift
//  TestApp
//
//  Created by Kraig Spear on 1/26/25.
//

import SwiftUI

struct TestCaseView: View {
    let instruction: TestCase
    let pageNumber: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Test Case \(pageNumber)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(instruction.title)
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Steps:")
                    .font(.headline)
                
                ForEach(instruction.steps, id: \.self) { step in
                    Text(step)
                }
            }
            
            VStack(alignment: .leading) {
                Text("Expected Outcome:")
                    .font(.headline)
                Text(instruction.expectedOutcome)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack {
                Spacer()
                FindLocationView()
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
