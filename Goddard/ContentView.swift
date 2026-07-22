//
//  ContentView.swift
//  Goddard
//
//  App root: owns the view model and lays out canvas + parameter panel,
//  mirroring calligramy's MainView (minus the mode strip / stage timeline).
//

import SwiftUI

struct ContentView: View {
    @StateObject private var fViewModel = TgoddardViewModel()

    var body: some View {
        HStack(spacing: 0) {
            MetalCanvasView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ParameterPanelView()
        }
        .environmentObject(fViewModel)
        .onAppear { fViewModel.buildOptimizer() }
        .frame(minWidth: 700, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
