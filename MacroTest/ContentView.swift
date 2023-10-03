//
//  ContentView.swift
//  MacroTest
//
//  Created by Andrii Chernenko on 2023-09-08.
//

import SwiftUI

struct ContentView: View {
    let url = URL(string: "https://www.google.com/search")!

    var body: some View {
        HStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text(url.host() ?? "")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
