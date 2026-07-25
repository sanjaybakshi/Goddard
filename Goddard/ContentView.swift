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
    @StateObject private var fEditor = TgoddardEditorState()

    var body: some View {
        HStack(spacing: 0) {
            MetalCanvasView(metal: fModel.fMetalViewModel)
                .aspectRatio(CGFloat(fModel.fOutputWidth) / CGFloat(fModel.fOutputHeight),
                             contentMode: .fit)
                .overlay {
                    if fEditor.editingGoalPlacement, fModel.fGoalImage != nil {
                        GoalPlacementOverlay(model: fModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)

            Divider()

            ParameterPanelView()
        }
        .environmentObject(fModel)
        .environmentObject(fEditor)
        .onAppear { fModel.buildOptimizer() }
        .frame(minWidth: 700, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
