//
//  ContentView.swift
//  Goddard
//
//  App root: owns the view model and lays out canvas + parameter panel,
//  mirroring calligramy's MainView (minus the mode strip / stage timeline).
//

import SwiftUI

struct ContentView: View {
    @StateObject private var fModel = TgoddardModel()

    var body: some View {
        HStack(spacing: 0) {
            MetalCanvasView(metal: fModel.fMetalViewModel)
                .aspectRatio(CGFloat(fModel.fOutputWidth) / CGFloat(fModel.fOutputHeight),
                             contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ParameterPanelView()
        }
        .environmentObject(fModel)
        .onAppear { fModel.buildOptimizer() }
        .frame(minWidth: 700, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
